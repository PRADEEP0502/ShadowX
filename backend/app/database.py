import os
from pathlib import Path

from dotenv import load_dotenv
from pymongo import MongoClient

# Try multiple possible .env locations because uvicorn/main.py working directory can differ.
BASE_DIR = Path(__file__).resolve().parent.parent.parent  # repoRoot

ENV_CANDIDATES = [
    BASE_DIR / "backend" / ".env",      # backend/.env
    Path.cwd() / ".env",               # ./ .env when running uvicorn from backend/
    BASE_DIR / "backend" / ".env",     # kept explicit
]

for candidate in ENV_CANDIDATES:
    if candidate and candidate.exists():
        load_dotenv(candidate)
        break

# Environment variables can be missing in local/CI when only testing routing.
# Do not hard-crash at import time.
MONGO_URI: str = os.getenv("MONGO_URI") or ""
DATABASE_NAME: str = os.getenv("DATABASE_NAME") or ""


_client = None
_db = None


def _get_db():
    global _client, _db
    if _db is not None and _client is not None:
        return _db

    if not MONGO_URI:
        raise RuntimeError("Missing environment variable: MONGO_URI")
    if not DATABASE_NAME:
        raise RuntimeError("Missing environment variable: DATABASE_NAME")

    try:
        _client = MongoClient(MONGO_URI)
        _db = _client[DATABASE_NAME]
        return _db
    except Exception as e:
        # Common on Windows networks: SRV DNS lookup fails for Atlas.
        # Keep the message short but actionable so client can see root cause.
        raise RuntimeError(
            f"MongoDB connection failed: {type(e).__name__}: {e}"
        ) from e



# Provide db + collections with minimal type issues and lazy evaluation.

def db():
    return _get_db()


def users_collection():
    return _get_db()["users"]


def messages_collection():
    return _get_db()["messages"]

