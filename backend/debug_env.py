import os
from pathlib import Path
from dotenv import load_dotenv

# Try multiple possible .env locations because uvicorn/main.py working directory can differ.
BASE_DIR = Path(__file__).resolve().parent.parent.parent  # repoRoot/backend
print(f"BASE_DIR: {BASE_DIR}")

ENV_CANDIDATES = [
    BASE_DIR / ".env",          # backend/.env
    Path.cwd() / ".env",       # ./ .env when running uvicorn from backend/
    BASE_DIR / ".env",         # kept explicit
]

for i, candidate in enumerate(ENV_CANDIDATES):
    print(f"Candidate {i}: {candidate}")
    print(f"  Exists: {candidate.exists()}")
    if candidate and candidate.exists():
        print(f"  Loading from {candidate}")
        load_dotenv(candidate)
        break

print(f"MONGO_URI: {os.getenv('MONGO_URI')}")
print(f"DATABASE_NAME: {os.getenv('DATABASE_NAME')}")