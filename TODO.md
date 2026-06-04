# TODO - Real-Time Chat WebSocket

## Plan (approved)
- [x] Inspect existing WebSocket and JWT auth mismatch
- [ ] Update `backend/app/routes/auth.py` so `/login` JWT includes `username` (and `email`)
- [ ] (Minor) Improve robustness in `backend/app/websocket/chat.py` message parsing
- [ ] Verify backend starts with `uvicorn` and websocket route is included
- [ ] Quick manual websocket test (connect + send `receiver:content`)

