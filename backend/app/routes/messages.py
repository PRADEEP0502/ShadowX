from fastapi import APIRouter

from app.database import messages_collection

router = APIRouter()


@router.get("/messages/{user1}/{user2}")
def get_messages(user1: str, user2: str):
    messages = list(
        messages_collection().find(
            {
                "$or": [
                    {"sender": user1, "receiver": user2},
                    {"sender": user2, "receiver": user1},
                ]
            },
            {"_id": 0},
        )
    )

    return messages

