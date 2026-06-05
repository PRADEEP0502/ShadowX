from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime, timedelta

from app.database import messages_collection

router = APIRouter()

VANISH_SECONDS = 60


class MarkSeenRequest(BaseModel):
    message_id: str


class SendMessageRequest(BaseModel):
    sender: str
    receiver: str
    message: str


@router.post("/messages")
def send_message(req: SendMessageRequest):
    """Save a new chat message in MongoDB.

    This endpoint is used by the Flutter chat screen Send button.
    """

    now = datetime.utcnow()

    from app.websocket.chat import active_connections
    receiver_online = req.receiver in active_connections
    status = "delivered" if receiver_online else "sent"

    doc = {
        "sender": req.sender,
        "receiver": req.receiver,
        "message": req.message,
        "created_at": now,
        "status": status,
        "seen_at": None,
    }

    res = messages_collection().insert_one(doc)
    print(f"[DEBUG] Message saved: {req.sender} -> {req.receiver} : {req.message}")

    # Return the created record fields; include Mongo _id.
    return {
        "_id": str(res.inserted_id),
        "sender": req.sender,
        "receiver": req.receiver,
        "message": req.message,
        "created_at": now.isoformat() + "Z",
        "status": status,
        "seen_at": None,
    }


@router.get("/messages/{user1}/{user2}")
def get_messages(user1: str, user2: str):
    """Fetch conversation history.

    Note: We exclude already-expired vanish messages so UI won't render them.
    """

    cutoff_time = datetime.utcnow() - timedelta(seconds=VANISH_SECONDS)

    messages = list(
        messages_collection().find(
            {
                "$or": [
                    {"sender": user1, "receiver": user2},
                    {"sender": user2, "receiver": user1},
                ],
                "$and": [
                    # Keep everything except vanish messages that are already past window.
                    {
                        "$or": [
                            {"status": {"$ne": "seen"}},
                            {
                                "$and": [
                                    {"status": "seen"},
                                    {
                                        "seen_at": {"$gt": cutoff_time},
                                    },
                                ]
                            },
                        ]
                    }
                ],
            }
        )
    )

    # Convert ObjectId to string and format datetimes to ISO strings with Z suffix.
    for m in messages:
        if "_id" in m and m["_id"] is not None:
            m["_id"] = str(m["_id"])
        
        created_at = m.get("created_at")
        if isinstance(created_at, datetime):
            m["created_at"] = created_at.isoformat() + "Z"
            
        seen_at = m.get("seen_at")
        if isinstance(seen_at, datetime):
            m["seen_at"] = seen_at.isoformat() + "Z"

    return messages



@router.post("/messages/{message_id}/seen")
async def mark_message_seen(message_id: str):
    """Mark a message as seen and broadcast status update to both parties."""

    from bson import ObjectId
    from bson.errors import InvalidId
    from app.websocket.chat import send_message as ws_send_message

    now = datetime.utcnow()

    try:
        oid = ObjectId(message_id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="Invalid message ID")

    # Fetch current message so we know sender/receiver for broadcasting.
    msg = messages_collection().find_one({"_id": oid})
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")

    # Skip if already seen (idempotent)
    if msg.get("status") == "seen":
        seen_at = msg.get("seen_at")
        return {"ok": True, "status": "seen", "seen_at": (seen_at.isoformat() + "Z") if seen_at else (now.isoformat() + "Z")}

    messages_collection().update_one(
        {"_id": oid},
        {"$set": {"status": "seen", "seen_at": now}},
    )

    print(f"[DEBUG] Message {message_id} marked seen at {now}")

    created_at = msg.get("created_at")

    payload = {
        "_id": message_id,
        "sender": str(msg.get("sender", "")),
        "receiver": str(msg.get("receiver", "")),
        "message": str(msg.get("message", "")),
        "created_at": (created_at.isoformat() + "Z") if hasattr(created_at, 'isoformat') else "",
        "status": "seen",
        "seen_at": now.isoformat() + "Z",
    }

    # Broadcast seen status to both sender and receiver via WebSocket.
    try:
        await ws_send_message(payload["sender"], payload)
        await ws_send_message(payload["receiver"], payload)
    except Exception as e:
        print(f"[DEBUG] WS broadcast seen failed: {e}")

    return {"ok": True, "status": "seen", "seen_at": now.isoformat() + "Z"}




@router.post("/messages/cleanup/vanish")
def cleanup_vanish_messages():
    """Delete expired vanish messages (status=seen older than 60s)."""

    cutoff_time = datetime.utcnow() - timedelta(seconds=VANISH_SECONDS)

    res = messages_collection().delete_many(
        {"status": "seen", "seen_at": {"$lte": cutoff_time}}
    )

    return {"ok": True, "deleted": res.deleted_count}


