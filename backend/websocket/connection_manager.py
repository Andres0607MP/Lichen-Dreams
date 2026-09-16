from typing import Dict, Set
from starlette.websockets import WebSocket


class ConnectionManager:
    def __init__(self):
        self._connections: Dict[int, Set[WebSocket]] = {}

    def connect(self, session_id: int, websocket: WebSocket):
        if session_id not in self._connections:
            self._connections[session_id] = set()
        self._connections[session_id].add(websocket)

    def disconnect(self, session_id: int, websocket: WebSocket):
        if session_id in self._connections:
            self._connections[session_id].discard(websocket)
            if not self._connections[session_id]:
                del self._connections[session_id]

    async def send_session_revoked(self, session_id: int):
        if session_id not in self._connections:
            return
        to_remove = []
        for ws in list(self._connections[session_id]):
            try:
                await ws.send_json({"type": "SESSION_REVOKED"})
            except Exception:
                to_remove.append(ws)
        for ws in to_remove:
            self.disconnect(session_id, ws)

    def clean_closed(self):
        for session_id in list(self._connections.keys()):
            for ws in list(self._connections[session_id]):
                try:
                    if ws.client_state.closed:
                        self.disconnect(session_id, ws)
                except Exception:
                    self.disconnect(session_id, ws)


connection_manager = ConnectionManager()
