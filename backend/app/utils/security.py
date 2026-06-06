import os
from datetime import datetime, timedelta
import bcrypt
from jose import jwt

SECRET_KEY: str = os.getenv("JWT_SECRET") or ""
ALGORITHM = "HS256"

# Allow app startup even if JWT_SECRET is not set; endpoints will fail with
# a clear error only when token generation is attempted.
if not SECRET_KEY:
    SECRET_KEY = "__MISSING_JWT_SECRET__"


def _truncate_password_72_bytes(password: str) -> str:
    """passlib bcrypt needs max 72 BYTES.

    Some systems throw even after truncation because of encoding edge cases.
    This guarantees the *bytes* length will be <= 72.
    """
    b = password.encode("utf-8")
    if len(b) <= 72:
        return password

    b = b[:72]
    # Decode a safe UTF-8 string; then re-trim to ensure bytes <= 72.
    s = b.decode("utf-8", errors="ignore")
    while len(s.encode("utf-8")) > 72:
        s = s[:-1]
    return s


def hash_password(password: str) -> str:
    # Ensure bcrypt backend never sees >72 bytes.
    truncated = _truncate_password_72_bytes(password)
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(truncated.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def verify_password(password: str, hashed_password: str) -> bool:
    try:
        truncated = _truncate_password_72_bytes(password)
        return bcrypt.checkpw(truncated.encode("utf-8"), hashed_password.encode("utf-8"))
    except Exception:
        return False


def create_access_token(data: dict):
    payload = data.copy()

    expire = datetime.utcnow() + timedelta(days=7)

    payload.update({"exp": expire})

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

