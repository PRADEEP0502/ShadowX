"""OTP endpoints for registration and forgot-password flows."""

import random
import string
from datetime import datetime, timedelta

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr

from app.database import otps_collection, users_collection
from app.utils.email import send_otp_email
from app.utils.security import hash_password

router = APIRouter(prefix="/otp", tags=["otp"])

OTP_EXPIRY_MINUTES = 5


# ─────────────────────────────────────────────
# Pydantic models
# ─────────────────────────────────────────────

class SendRegisterOtpRequest(BaseModel):
    username: str
    email: EmailStr
    password: str


class VerifyRegisterOtpRequest(BaseModel):
    email: EmailStr
    otp: str


class SendForgotOtpRequest(BaseModel):
    email: EmailStr


class VerifyForgotOtpRequest(BaseModel):
    email: EmailStr
    otp: str
    new_password: str


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def _generate_otp() -> str:
    return "".join(random.choices(string.digits, k=6))


def _get_valid_otp(email: str, purpose: str) -> dict | None:
    """Return a non-expired OTP document or None."""
    now = datetime.utcnow()
    doc = otps_collection().find_one(
        {"email": email, "purpose": purpose, "expires_at": {"$gt": now}}
    )
    return doc


# ─────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────

@router.post("/send-register")
def send_register_otp(req: SendRegisterOtpRequest):
    """Step 1 of registration: validate uniqueness, store pending data + OTP, send email."""

    # Check for existing user
    existing = users_collection().find_one(
        {"$or": [{"email": req.email}, {"username": req.username}]}
    )
    if existing:
        raise HTTPException(status_code=400, detail="Email or username already registered")

    otp = _generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=OTP_EXPIRY_MINUTES)

    # Upsert: replace any existing pending OTP for this email
    otps_collection().delete_many({"email": req.email, "purpose": "register"})
    otps_collection().insert_one({
        "email": req.email,
        "otp": otp,
        "purpose": "register",
        "expires_at": expires_at,
        "username": req.username,
        "password_hash": hash_password(req.password),
    })

    print(f"[DEBUG] Register OTP for {req.email}: {otp}")

    email_sent = True
    email_error = ""
    try:
        send_otp_email(req.email, otp, purpose="register")
    except RuntimeError as e:
        email_sent = False
        email_error = str(e)
        print(f"[DEBUG] Email send failed: {email_error}")

    response: dict = {
        "message": f"OTP sent to {req.email}. Valid for {OTP_EXPIRY_MINUTES} minutes."
        if email_sent
        else f"Email delivery failed — use OTP below to test. Fix MAIL_PASSWORD in .env for production.",
        "email_sent": email_sent,
        # DEV HELPER: otp_hint returned so you can test without email.
        # Remove this field before going to production.
        "otp_hint": otp,
    }
    if not email_sent:
        response["email_error"] = email_error

    return response


@router.post("/verify-register")
def verify_register_otp(req: VerifyRegisterOtpRequest):
    """Step 2 of registration: verify OTP and create the user account."""

    doc = _get_valid_otp(req.email, "register")

    if not doc:
        raise HTTPException(status_code=400, detail="OTP expired or not found. Please request a new one.")

    if doc["otp"] != req.otp.strip():
        raise HTTPException(status_code=400, detail="Incorrect OTP")

    # Check again in case someone registered between send and verify
    existing = users_collection().find_one(
        {"$or": [{"email": req.email}, {"username": doc["username"]}]}
    )
    if existing:
        raise HTTPException(status_code=400, detail="Email or username already registered")

    users_collection().insert_one({
        "username": doc["username"],
        "email": req.email,
        "password": doc["password_hash"],
    })

    # Clean up OTP
    otps_collection().delete_many({"email": req.email, "purpose": "register"})

    print(f"[DEBUG] User {doc['username']} registered successfully via OTP")

    return {"message": "Account created successfully! You can now log in."}


@router.post("/send-forgot")
def send_forgot_otp(req: SendForgotOtpRequest):
    """Step 1 of forgot password: verify email exists, send OTP."""

    user = users_collection().find_one({"email": req.email})
    if not user:
        raise HTTPException(status_code=404, detail="No account found with this email")

    otp = _generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=OTP_EXPIRY_MINUTES)

    otps_collection().delete_many({"email": req.email, "purpose": "forgot"})
    otps_collection().insert_one({
        "email": req.email,
        "otp": otp,
        "purpose": "forgot",
        "expires_at": expires_at,
    })

    print(f"[DEBUG] Forgot password OTP for {req.email}: {otp}")

    email_sent = True
    email_error = ""
    try:
        send_otp_email(req.email, otp, purpose="forgot")
    except RuntimeError as e:
        email_sent = False
        email_error = str(e)
        print(f"[DEBUG] Email send failed: {email_error}")

    response: dict = {
        "message": f"OTP sent to {req.email}. Valid for {OTP_EXPIRY_MINUTES} minutes."
        if email_sent
        else f"Email delivery failed — use OTP below to test. Fix MAIL_PASSWORD in .env for production.",
        "email_sent": email_sent,
        # DEV HELPER: otp_hint returned so you can test without email.
        # Remove this field before going to production.
        "otp_hint": otp,
    }
    if not email_sent:
        response["email_error"] = email_error

    return response


@router.post("/verify-forgot")
def verify_forgot_otp(req: VerifyForgotOtpRequest):
    """Step 2 of forgot password: verify OTP and update password."""

    doc = _get_valid_otp(req.email, "forgot")

    if not doc:
        raise HTTPException(status_code=400, detail="OTP expired or not found. Please request a new one.")

    if doc["otp"] != req.otp.strip():
        raise HTTPException(status_code=400, detail="Incorrect OTP")

    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    users_collection().update_one(
        {"email": req.email},
        {"$set": {"password": hash_password(req.new_password)}},
    )

    otps_collection().delete_many({"email": req.email, "purpose": "forgot"})

    print(f"[DEBUG] Password reset successfully for {req.email}")

    return {"message": "Password reset successfully! You can now log in."}
