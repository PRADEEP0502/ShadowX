from fastapi import APIRouter

from app.websocket.chat import get_online_users

router = APIRouter()


@router.get("/online-users")
def online_users():
    users = get_online_users()
    return {"count": len(users), "users": users}

