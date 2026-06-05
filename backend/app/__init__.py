from fastapi import FastAPI
from app.routes import users, auth, messages, status, websocket, conversations, otp

from app.cors import setup_cors

from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

app = FastAPI()
setup_cors(app)

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    import sys
    print("--- VALIDATION ERROR ---", file=sys.stderr)
    print(f"URL: {request.url}", file=sys.stderr)
    print(f"Errors: {exc.errors()}", file=sys.stderr)
    try:
        body = await request.body()
        print(f"Body: {body.decode()}", file=sys.stderr)
    except Exception:
        pass
    print("------------------------", file=sys.stderr)
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()},
    )

app.include_router(users.router)
app.include_router(auth.router)
app.include_router(messages.router)
app.include_router(status.router)
app.include_router(websocket.router)
app.include_router(conversations.router)
app.include_router(otp.router)




