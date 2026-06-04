# Convenience re-export so `uvicorn main:app` works from repo root.
import os
import sys

# Ensure `backend/` is on sys.path so imports like `from app.database ...` work.
BACKEND_DIR = os.path.dirname(__file__)
sys.path.insert(0, BACKEND_DIR)

from app import app