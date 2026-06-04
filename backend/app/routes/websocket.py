from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from datetime import datetime

from app.websocket.chat import connect as ws_connect, disconnect as ws_disconnect, active_connections
from app.websocket.chat import send_message as ws_send_message
from app.database import messages_collection

router = APIRouter()


class IncomingWSMessage(BaseModel):
    receiver: str
    message: str


@router.websocket("/ws/{username}")
async def websocket_endpoint(websocket: WebSocket, username: str):
    await ws_connect(username, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            incoming = IncomingWSMessage(**data)

            now = datetime.utcnow()
            doc = {
                "sender": username,
                "receiver": incoming.receiver,
                "message": incoming.message,
                "created_at": now,
                "status": "sent",
                "seen_at": None,
            }
            res = messages_collection().insert_one(doc)

            # Send to receiver in real time (and to sender too, for instant UI).
            payload = {
                "_id": str(res.inserted_id),
                "sender": username,
                "receiver": incoming.receiver,
                "message": incoming.message,
                "created_at": now.isoformat(),
                "status": "sent",
                "seen_at": None,
            }

            # receiver
            await ws_send_message(incoming.receiver, payload)
            # sender echo (optional but helpful for UX)
            await ws_send_message(username, payload)

    except WebSocketDisconnect:
        ws_disconnect(username)
    except Exception:
        ws_disconnect(username)
        # Let disconnect clean up.

