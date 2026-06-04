from fastapi import FastAPI
from app.routes import users, auth, messages, status

app = FastAPI()
app.include_router(users.router)
app.include_router(auth.router)
app.include_router(messages.router)
app.include_router(status.router)