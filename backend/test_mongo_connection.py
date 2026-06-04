import os
from pymongo import MongoClient

# Load environment variables from .env (same as in database.py)
from dotenv import load_dotenv
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent  # repoRoot/backend
ENV_CANDIDATES = [
    BASE_DIR / ".env",
    Path.cwd() / ".env",
    BASE_DIR / ".env",
]

for candidate in ENV_CANDIDATES:
    if candidate and candidate.exists():
        load_dotenv(candidate)
        break

MONGO_URI = os.getenv("MONGO_URI") or ""
DATABASE_NAME = os.getenv("DATABASE_NAME") or ""

print(f"MONGO_URI: {MONGO_URI}")
print(f"DATABASE_NAME: {DATABASE_NAME}")

if not MONGO_URI:
    print("Missing MONGO_URI")
    exit(1)

if not DATABASE_NAME:
    print("Missing DATABASE_NAME")
    exit(1)

try:
    client = MongoClient(MONGO_URI)
    db = client[DATABASE_NAME]
    # Try to ping the server
    db.command("ping")
    print("Successfully connected to MongoDB!")
except Exception as e:
    print(f"Failed to connect: {e}")
    import traceback
    traceback.print_exc()