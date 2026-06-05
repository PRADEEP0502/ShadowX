from fastapi import APIRouter
from datetime import datetime

from app.database import messages_collection

router = APIRouter()


def _format_timestamp(ts):
    # Mongo may store datetimes; we always return ISO string with 'Z' suffix.
    if ts is None:
        return datetime.utcnow().isoformat() + "Z"
    if isinstance(ts, datetime):
        return ts.isoformat() + "Z"
    s = str(ts)
    if s and not s.endswith("Z"):
        return s + "Z"
    return s


@router.get("/conversations/{username}")
def get_conversations(username: str):
    """Return WhatsApp-style conversation list for a user.

    Response format:
    [
      {"username":"praveen","last_message":"Hi","timestamp":"..."}
    ]

    Logic:
    - Look at all messages where username is sender or receiver
    - Group by the other participant
    - For each group, return the latest message + its timestamp
    """

    username = username.strip()
    if not username:
        return []

    # Fetch messages relevant to the user.
    docs = list(messages_collection().find(
        {
            "$or": [{"sender": username}, {"receiver": username}],
            "deleted_for": {"$ne": username}
        },
        {"sender": 1, "receiver": 1, "message": 1, "created_at": 1, "status": 1},
    ))

    # Unread count per other participant (WhatsApp-style badge)
    # Meaning: messages where `other` is the sender and `username` is the receiver,
    # and the message is not yet "seen".
    unread = {}

    # Build latest per other user.

    latest = {}
    for doc in docs:
        sender = (doc.get("sender") or "").strip()
        receiver = (doc.get("receiver") or "").strip()
        message = doc.get("message")
        message = message if message is not None else ""
        message = str(message)
        created_at = doc.get("created_at")

        if sender == username:
            other = receiver
        else:
            other = sender

        if not other:
            continue

        prev = latest.get(other)
        if prev is None:
            latest[other] = {
                "username": other,
                "last_message": message,
                "timestamp": _format_timestamp(created_at),
                "_created_at_obj": created_at,
            }
            continue

        prev_created = prev.get("_created_at_obj")

        # Compare datetimes when possible, else fall back to string.
        if isinstance(prev_created, datetime) and isinstance(created_at, datetime):
            if created_at > prev_created:
                latest[other] = {
                    "username": other,
                    "last_message": message,
                    "timestamp": _format_timestamp(created_at),
                    "_created_at_obj": created_at,
                }
        else:
            # Non-standard type; compare ISO strings.
            if _format_timestamp(created_at) > _format_timestamp(prev_created):
                latest[other] = {
                    "username": other,
                    "last_message": message,
                    "timestamp": _format_timestamp(created_at),
                    "_created_at_obj": created_at,
                }

    # Compute unread counts now that we know latest participants.
    for doc in docs:
        sender = (doc.get("sender") or "").strip()
        receiver = (doc.get("receiver") or "").strip()

        other = None
        if receiver == username:
            other = sender

        if not other:
            continue

        status = (doc.get("status") or "").strip()
        if status != "seen":
            unread[other] = unread.get(other, 0) + 1

    # Attach unread_count into the latest items.
    # If a conversation has no unread messages, unread_count is 0.
    for other, item in latest.items():
        item["unread_count"] = unread.get(other, 0)

    # Sort by timestamp (desc).
    items = list(latest.values())


    items.sort(key=lambda x: x.get("timestamp"), reverse=True)

    # Strip internal key.
    for it in items:
        it.pop("_created_at_obj", None)

    return items

