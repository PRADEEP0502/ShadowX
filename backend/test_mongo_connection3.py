import os
from pathlib import Path
from dotenv import load_dotenv

# Try multiple possible .env locations because uvicorn/main.py working directory can differ.
# We are in the backend directory, so we go up two levels to get to the repo root.
BASE_DIR = Path(__file__).resolve().parent.parent  # repoRoot

ENV_CANDIDATES = [
    BASE_DIR / "backend" / ".env",          # backend/.env
    Path.cwd() / ".env",       # ./ .env when running uvicorn from backend/
    BASE_DIR / "backend" / ".env",         # kept explicit
]

for i, candidate in enumerate(ENV_CANDIDATES):
    print(f"Candidate {i}: {candidate}")
    print(f"  Exists: {candidate.exists()}")
    if candidate and candidate.exists():
        print(f"  Loading from {candidate}")
        load_dotenv(candidate)
        break

# Environment variables can be missing in local/CI when only testing routing.
# Do not hard-crash at import time.
MONGO_URI: str = os.getenv("MONGO_URI") or ""
DATABASE_NAME: str = os.getenv("DATABASE_NAME") or ""

print(f"MONGO_URI: {MONGO_URI}")
print(f"DATABASE_NAME: {DATABASE_NAME}")

if not MONGO_URI:
    print("Missing MONGO_URI")
    exit(1)

if not DATABASE_NAME:
    print("Missing DATABASE_NAME")
    exit(1)

from pymongo import MongoClient

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