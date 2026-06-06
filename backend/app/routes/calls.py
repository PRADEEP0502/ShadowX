from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

from app.database import calls_collection

router = APIRouter()


class SaveCallRequest(BaseModel):
    caller: str
    receiver: str
    call_type: str        # "voice" | "video"
    status: str           # "outgoing" | "incoming" | "missed" | "completed"
    duration: int = 0     # seconds


@router.post("/calls")
def save_call(req: SaveCallRequest):
    """Save a call record to MongoDB."""
    doc = {
        "caller": req.caller,
        "receiver": req.receiver,
        "call_type": req.call_type,
        "status": req.status,
        "duration": req.duration,
        "timestamp": datetime.utcnow(),
    }
    res = calls_collection().insert_one(doc)
    return {
        "_id": str(res.inserted_id),
        "caller": req.caller,
        "receiver": req.receiver,
        "call_type": req.call_type,
        "status": req.status,
        "duration": req.duration,
        "timestamp": doc["timestamp"].isoformat() + "Z",
    }


@router.get("/calls/{username}")
def get_calls(username: str):
    """Fetch all call logs for a user (as caller or receiver), sorted newest first."""
    docs = list(
        calls_collection().find(
            {"$or": [{"caller": username}, {"receiver": username}]}
        ).sort("timestamp", -1).limit(200)
    )
    for d in docs:
        d["_id"] = str(d["_id"])
        ts = d.get("timestamp")
        if isinstance(ts, datetime):
            d["timestamp"] = ts.isoformat() + "Z"
    return docs


@router.delete("/calls/{call_id}")
def delete_call(call_id: str):
    """Delete a single call log entry."""
    from bson import ObjectId
    from bson.errors import InvalidId
    try:
        oid = ObjectId(call_id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="Invalid call ID")
    res = calls_collection().delete_one({"_id": oid})
    if res.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Call not found")
    return {"ok": True}
