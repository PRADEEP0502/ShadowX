from fastapi import WebSocket

active_connections = {}

async def connect(username, websocket):
    await websocket.accept()
    active_connections[username] = websocket

def disconnect(username):
    active_connections.pop(username, None)

async def send_message(receiver, message):
    if receiver in active_connections:
        await active_connections[receiver].send_json(message)
        return True
    return False


def get_online_users():
    return list(active_connections.keys())
