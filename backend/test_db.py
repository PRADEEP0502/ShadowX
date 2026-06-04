import sys
sys.path.insert(0, "C:\\Project X\\backend")

from app.database import db

try:
    database = db()
    print("Successfully got database")
    # Try to get the users collection
    users = database["users"]
    print("Successfully got users collection")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()