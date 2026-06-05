from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr

from app.database import users_collection, messages_collection, otps_collection
from app.utils.security import hash_password, verify_password

router = APIRouter()


class ProfileUpdate(BaseModel):
    current_username: str
    new_username: str
    email: EmailStr
    avatar: str | None = None
    status: str = "Online"
    notification_push: bool = True
    notification_sound: bool = True
    notification_vibrate: bool = True
    notification_preview: bool = True


class PasswordChange(BaseModel):
    username: str
    old_password: str
    new_password: str


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


@router.get("/users/profile/{username}")
def get_user_profile(username: str):
    user = users_collection().find_one({"username": username})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "username": user.get("username"),
        "email": user.get("email"),
        "avatar": user.get("avatar"),
        "status": user.get("status", "Online"),
        "notification_push": user.get("notification_push", True),
        "notification_sound": user.get("notification_sound", True),
        "notification_vibrate": user.get("notification_vibrate", True),
        "notification_preview": user.get("notification_preview", True),
    }


@router.post("/users/profile/update")
def update_user_profile(req: ProfileUpdate):
    users_col = users_collection()
    
    # Verify current user exists
    user = users_col.find_one({"username": req.current_username})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # If username is changing, verify new username is not already taken
    if req.new_username != req.current_username:
        existing = users_col.find_one({"username": req.new_username})
        if existing:
            raise HTTPException(status_code=400, detail="Username already taken")
            
        # Rename username references across messages and otps
        messages_collection().update_many({"sender": req.current_username}, {"$set": {"sender": req.new_username}})
        messages_collection().update_many({"receiver": req.current_username}, {"$set": {"receiver": req.new_username}})
        otps_collection().update_many({"username": req.current_username}, {"$set": {"username": req.new_username}})
        
    # Update fields in user document
    users_col.update_one(
        {"username": req.current_username},
        {
            "$set": {
                "username": req.new_username,
                "email": req.email,
                "avatar": req.avatar,
                "status": req.status,
                "notification_push": req.notification_push,
                "notification_sound": req.notification_sound,
                "notification_vibrate": req.notification_vibrate,
                "notification_preview": req.notification_preview,
            }
        }
    )
    
    return {"message": "Profile updated successfully", "username": req.new_username}


@router.post("/users/profile/change-password")
def change_user_password(req: PasswordChange):
    users_col = users_collection()
    user = users_col.find_one({"username": req.username})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Verify old password
    if not verify_password(req.old_password, user["password"]):
        raise HTTPException(status_code=400, detail="Incorrect current password")
        
    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters")
        
    # Update password hash
    users_col.update_one(
        {"username": req.username},
        {"$set": {"password": hash_password(req.new_password)}}
    )
    
    return {"message": "Password changed successfully"}
