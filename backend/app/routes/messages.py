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

    doc = {
        "sender": req.sender,
        "receiver": req.receiver,
        "message": req.message,
        "created_at": now,
        # Vanish mode: a freshly-sent message is immediately "sent".
        "status": "sent",
        "seen_at": None,
    }

    res = messages_collection().insert_one(doc)

    # Return the created record fields; include Mongo _id.
    return {
        "_id": str(res.inserted_id),
        "sender": req.sender,
        "receiver": req.receiver,
        "message": req.message,
        "created_at": now.isoformat(),
        "status": "sent",
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
            },
            {"_id": 0},
        )
    )

    return messages


@router.post("/messages/{message_id}/seen")
def mark_message_seen(message_id: str):
    """Mark a message as seen and start vanish countdown."""

    now = datetime.utcnow()

    result = messages_collection().update_one(
        {"_id": message_id},
        {"$set": {"status": "seen", "seen_at": now}},
    )

    if result.matched_count == 0:
        # If message_id doesn't exist or isn't stored as same type.
        raise HTTPException(status_code=404, detail="Message not found")

    return {"ok": True, "status": "seen", "seen_at": now.isoformat()}


@router.post("/messages/cleanup/vanish")
def cleanup_vanish_messages():
    """Delete expired vanish messages (status=seen older than 60s)."""

    cutoff_time = datetime.utcnow() - timedelta(seconds=VANISH_SECONDS)

    res = messages_collection().delete_many(
        {"status": "seen", "seen_at": {"$lte": cutoff_time}}
    )

    return {"ok": True, "deleted": res.deleted_count}


