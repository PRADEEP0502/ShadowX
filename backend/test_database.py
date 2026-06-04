import sys
sys.path.insert(0, "C:\\Project X\\backend")

from app.database import db

try:
    database = db()
    print("Database object:", database)
    users = database["users"]
    print("Users collection:", users)
    # The count_documents method might fail if the collection doesn't exist, but that's okay.
    # We'll just check that we can call it without connection error.
    count = users.count_documents({})
    print(f"Document count: {count}")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()