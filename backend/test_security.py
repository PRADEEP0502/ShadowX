import sys
sys.path.insert(0, "C:\\Project X\\backend")

from app.utils.security import hash_password, verify_password

# Test with a short password
password = "hello"
hashed = hash_password(password)
print(f"Hashed: {hashed}")
print(f"Verify: {verify_password(password, hashed)}")

# Test with a long password (longer than 72 bytes)
long_password = "a" * 100
hashed_long = hash_password(long_password)
print(f"Long hashed: {hashed_long}")
print(f"Long verify: {verify_password(long_password, hashed_long)}")