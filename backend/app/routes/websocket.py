from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from datetime import datetime

from app.websocket.chat import connect as ws_connect, disconnect as ws_disconnect, active_connections
from app.websocket.chat import send_message as ws_send_message
from app.database import messages_collection, users_collection

router = APIRouter()


class IncomingWSMessage(BaseModel):
    receiver: str
    message: str
    message_type: str = "text"


async def broadcast_status(username: str, is_online: bool):
    now = datetime.utcnow()
    last_seen_str = None
    if is_online:
        users_collection().update_one(
            {"username": username},
            {"$set": {"is_online": True}}
        )
    else:
        users_collection().update_one(
            {"username": username},
            {"$set": {"is_online": False, "last_seen": now}}
        )
        last_seen_str = now.isoformat() + "Z"

    payload = {
        "type": "status",
        "username": username,
        "is_online": is_online,
        "last_seen": last_seen_str
    }
    for conn_username in list(active_connections.keys()):
        await ws_send_message(conn_username, payload)


@router.websocket("/ws/{username}")
async def websocket_endpoint(websocket: WebSocket, username: str):
    await ws_connect(username, websocket)
    print(f"[DEBUG] WebSocket connected for user: {username}")

    # Mark any pending "sent" messages to this user as "delivered" since they are now online.
    try:
        sent_messages = list(
            messages_collection().find(
                {"receiver": username, "status": "sent"}
            )
        )
        if sent_messages:
            messages_collection().update_many(
                {"receiver": username, "status": "sent"},
                {"$set": {"status": "delivered"}},
            )
            print(f"[DEBUG] Marked {len(sent_messages)} pending messages as delivered to {username}")
            for msg in sent_messages:
                msg_id = str(msg["_id"])
                sender = msg["sender"]
                payload = {
                    "_id": msg_id,
                    "sender": sender,
                    "receiver": username,
                    "message": msg["message"],
                    "created_at": (msg["created_at"].isoformat() + "Z") if hasattr(msg["created_at"], "isoformat") else "",
                    "status": "delivered",
                    "seen_at": None,
                }
                await ws_send_message(sender, payload)
                await ws_send_message(username, payload)
    except Exception as e:
        print(f"[DEBUG] Failed to mark pending messages as delivered: {e}")

    try:
        await broadcast_status(username, True)
        while True:
            data = await websocket.receive_json()
            print(f"[DEBUG] Message received on WS from {username}: {data}")

            msg_type = data.get("type", "message")
            if msg_type == "typing":
                receiver = data.get("receiver")
                if receiver:
                    typing_payload = {
                        "type": "typing",
                        "sender": username,
                        "receiver": receiver
                    }
                    await ws_send_message(receiver, typing_payload)
                continue

            incoming = IncomingWSMessage(**data)

            now = datetime.utcnow()

            receiver_online = incoming.receiver in active_connections
            status = "delivered" if receiver_online else "sent"

            doc = {
                "sender": username,
                "receiver": incoming.receiver,
                "message": incoming.message,
                "message_type": incoming.message_type,
                "created_at": now,
                "status": status,
                "seen_at": None,
            }
            res = messages_collection().insert_one(doc)
            print(f"[DEBUG] Message saved: {username} -> {incoming.receiver} : {incoming.message} ({incoming.message_type})")

            payload = {
                "_id": str(res.inserted_id),
                "sender": username,
                "receiver": incoming.receiver,
                "message": incoming.message,
                "message_type": incoming.message_type,
                "created_at": now.isoformat() + "Z",
                "status": status,
                "seen_at": None,
            }

            # receiver
            await ws_send_message(incoming.receiver, payload)
            # sender echo (optional but helpful for UX)
            await ws_send_message(username, payload)

    except WebSocketDisconnect:
        ws_disconnect(username)
        await broadcast_status(username, False)
        print(f"[DEBUG] WebSocket disconnected for user: {username}")
    except Exception as e:
        ws_disconnect(username)
        await broadcast_status(username, False)
        print(f"[DEBUG] WebSocket error for user: {username}: {e}")
