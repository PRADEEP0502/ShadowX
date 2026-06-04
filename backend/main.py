"""Repo root entrypoint.

Also hosts startup background jobs.
"""

import os
import sys
import asyncio
from datetime import datetime, timedelta

# Ensure `backend/` is on sys.path so imports like `from app.database ...` work.
BACKEND_DIR = os.path.dirname(__file__)
sys.path.insert(0, BACKEND_DIR)

from app import app
from app.database import messages_collection

VANISH_SECONDS = 60
CLEANUP_EVERY_SECONDS = 5


async def _vanish_cleanup_loop():
    while True:
        try:
            cutoff_time = datetime.utcnow() - timedelta(seconds=VANISH_SECONDS)
            messages_collection().delete_many(
                {"status": "seen", "seen_at": {"$lte": cutoff_time}}
            )
        except Exception:
            # Keep loop alive even if mongo has transient failures.
            pass

        await asyncio.sleep(CLEANUP_EVERY_SECONDS)


@app.on_event("startup")
async def _startup():
    # Run vanish cleanup background task.
    asyncio.create_task(_vanish_cleanup_loop())

