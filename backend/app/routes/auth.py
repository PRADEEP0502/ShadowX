from fastapi import APIRouter, HTTPException

from app.database import users_collection

from app.models.user import UserLogin, UserRegister

from app.utils.security import create_access_token, hash_password, verify_password


def _users_col():
    return users_collection()


router = APIRouter()


@router.post("/register")
def register(user: UserRegister):
    existing_user = _users_col().find_one(
        {
            "$or": [
                {"email": user.email},
                {"username": user.username},
            ]
        }
    )

    if existing_user:
        raise HTTPException(status_code=400, detail="User already exists")

    _users_col().insert_one(
        {
            "username": user.username,
            "email": user.email,
            "password": hash_password(user.password),
        }
    )

    return {"message": "User registered successfully"}



@router.post("/login")
def login(user: UserLogin):
    db_user = _users_col().find_one({"email": user.email})

    if not db_user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not verify_password(user.password, db_user["password"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({
        "email": db_user["email"],
        "username": db_user["username"],
    })

    return {
        "access_token": token,
        "username": db_user["username"],
    }


