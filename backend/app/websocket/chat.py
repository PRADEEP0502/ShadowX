from fastapi import WebSocket

active_connections = {}

# NOTE: This module is currently a lightweight websocket utility.
# Business logic like persisting messages lives in websocket consumers/routes.

async def connect(username, websocket):
    await websocket.accept()
    active_connections[username] = websocket

def disconnect(username):
    active_connections.pop(username, None)

async def send_message(receiver, message: dict):
    """Send a message/status payload to a connected websocket user."""
    if receiver in active_connections:
        await active_connections[receiver].send_json(message)
        return True
    return False



def get_online_users():
    return list(active_connections.keys())

