from fastapi import FastAPI
from app.routes import users, auth, messages, status
from app.cors import setup_cors

app = FastAPI()
setup_cors(app)

app.include_router(users.router)
app.include_router(auth.router)
app.include_router(messages.router)
app.include_router(status.router)
