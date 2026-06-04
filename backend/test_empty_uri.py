from pymongo import MongoClient
try:
    client = MongoClient("")
    print("Unexpected success")
except Exception as e:
    print(f"Error with empty string: {e}")
    import traceback
    traceback.print_exc()