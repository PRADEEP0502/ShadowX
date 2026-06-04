from fastapi import APIRouter

from app.database import users_collection

router = APIRouter()


@router.get("/users/search")
def search_users(username: str):
    users = list(
        users_collection().find(
            {
                "username": {
                    "$regex": username,
                    "$options": "i",
                }
            },
            {
                "_id": 0,
                "password": 0,
            },
        )
    )

    return users

