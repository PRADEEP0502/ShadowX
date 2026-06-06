import os
from fastapi import APIRouter, HTTPException, UploadFile, File, Request
from pydantic import BaseModel
from datetime import datetime, timedelta
import cloudinary
import cloudinary.uploader

from app.database import messages_collection

router = APIRouter()

# Configure Cloudinary
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

VANISH_SECONDS = 60


class MarkSeenRequest(BaseModel):
    message_id: str


class SendMessageRequest(BaseModel):
    sender: str
    receiver: str
    message: str
    message_type: str = "text"


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
        "message_type": req.message_type,
        "created_at": now,
        "status": status,
        "seen_at": None,
    }

    res = messages_collection().insert_one(doc)
    print(f"[DEBUG] Message saved: {req.sender} -> {req.receiver} : {req.message} ({req.message_type})")

    # Return the created record fields; include Mongo _id.
    return {
        "_id": str(res.inserted_id),
        "sender": req.sender,
        "receiver": req.receiver,
        "message": req.message,
        "message_type": req.message_type,
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
                "deleted_for": {"$ne": user1},
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
            
        m["is_deleted_everyone"] = m.get("is_deleted_everyone", False)
        m["deleted_for"] = m.get("deleted_for", [])
        m["message_type"] = m.get("message_type", "text")

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




class DeleteForMeRequest(BaseModel):
    username: str


class DeleteEveryoneRequest(BaseModel):
    username: str


@router.post("/messages/{message_id}/delete-for-me")
def delete_for_me(message_id: str, req: DeleteForMeRequest):
    from bson import ObjectId
    from bson.errors import InvalidId

    try:
        oid = ObjectId(message_id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="Invalid message ID")

    res = messages_collection().update_one(
        {"_id": oid},
        {"$addToSet": {"deleted_for": req.username}}
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Message not found")

    return {"ok": True}


@router.post("/messages/{message_id}/delete-everyone")
async def delete_everyone(message_id: str, req: DeleteEveryoneRequest):
    from bson import ObjectId
    from bson.errors import InvalidId
    from app.websocket.chat import send_message as ws_send_message

    try:
        oid = ObjectId(message_id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="Invalid message ID")

    msg = messages_collection().find_one({"_id": oid})
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")

    if msg.get("sender") != req.username:
        raise HTTPException(status_code=403, detail="You can only delete your own messages for everyone")

    messages_collection().update_one(
        {"_id": oid},
        {"$set": {
            "message": "This message was deleted",
            "is_deleted_everyone": True
        }}
    )

    created_at = msg.get("created_at")
    seen_at = msg.get("seen_at")

    # Broadcast updated message to both sender and receiver
    payload = {
        "type": "delete_everyone",
        "_id": message_id,
        "sender": msg["sender"],
        "receiver": msg["receiver"],
        "message": "This message was deleted",
        "is_deleted_everyone": True,
        "created_at": (created_at.isoformat() + "Z") if hasattr(created_at, "isoformat") else "",
        "status": msg.get("status", "sent"),
        "seen_at": (seen_at.isoformat() + "Z") if hasattr(seen_at, "isoformat") else None,
        "deleted_for": msg.get("deleted_for", []),
    }

    try:
        await ws_send_message(msg["sender"], payload)
        await ws_send_message(msg["receiver"], payload)
    except Exception as e:
        print(f"[DEBUG] WS broadcast delete-everyone failed: {e}")

    return payload


@router.delete("/messages/conversation/{user1}/{user2}")
def delete_conversation(user1: str, user2: str):
    """Delete all messages between user1 and user2 from database."""
    res = messages_collection().delete_many({
        "$or": [
            {"sender": user1, "receiver": user2},
            {"sender": user2, "receiver": user1}
        ]
    })
    print(f"[DEBUG] Deleted {res.deleted_count} messages in conversation between {user1} and {user2}")
    return {"ok": True, "deleted_count": res.deleted_count}


@router.post("/messages/upload")
async def upload_image(request: Request, file: UploadFile = File(...)):
    """Upload an image to Cloudinary and return the secure URL.
    
    If Cloudinary is not configured, saves the image locally and returns a local static URL.
    """
    try:
        cloud_name = os.getenv("CLOUDINARY_CLOUD_NAME")
        api_key = os.getenv("CLOUDINARY_API_KEY")
        api_secret = os.getenv("CLOUDINARY_API_SECRET")

        if cloud_name and api_key and api_secret:
            content = await file.read()
            res = cloudinary.uploader.upload(content, folder="shadowchatx", resource_type="auto")
            return {"url": res.get("secure_url")}
        else:
            print("[DEBUG] Cloudinary not fully configured. Falling back to local static upload.")
            static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "uploads")
            os.makedirs(static_dir, exist_ok=True)
            
            import uuid
            ext = os.path.splitext(file.filename)[1] or ".png"
            unique_filename = f"{uuid.uuid4()}{ext}"
            filepath = os.path.join(static_dir, unique_filename)
            
            content = await file.read()
            with open(filepath, "wb") as f:
                f.write(content)
            
            base_url = str(request.base_url)
            url = f"{base_url.rstrip('/')}/static/uploads/{unique_filename}"
            print(f"[DEBUG] Local image saved to: {filepath}, served at: {url}")
            return {"url": url}
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Image upload failed: {str(e)}"
        )


