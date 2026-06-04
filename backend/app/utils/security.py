import os
from datetime import datetime, timedelta

# Patch bcrypt to add missing __about__ attribute for passlib compatibility
import bcrypt

if not hasattr(bcrypt, "__about__"):
    class About:
        # Pylance may not know about bcrypt's runtime attributes.
        __version__ = getattr(bcrypt, "__version__", "")  # type: ignore[attr-defined]

    bcrypt.__about__ = About()


from jose import jwt
from passlib.context import CryptContext

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
)

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


def hash_password(password: str):
    # Ensure bcrypt backend never sees >72 bytes.
    return pwd_context.hash(_truncate_password_72_bytes(password))


def verify_password(password: str, hashed_password: str):
    return pwd_context.verify(
        _truncate_password_72_bytes(password), hashed_password
    )


def create_access_token(data: dict):
    payload = data.copy()

    expire = datetime.utcnow() + timedelta(days=7)

    payload.update({"exp": expire})

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

