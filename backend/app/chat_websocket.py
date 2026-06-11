"""
Real-time chat infrastructure for the Mother <-> Doctor live chat.

Architecture
------------
- REST endpoints in `tools_endpoints.py` remain the source of truth for
  persistence (creating rooms, storing messages, marking-as-read).
- This module adds a WebSocket fan-out layer so connected clients see
  events instantly without polling.

Wire protocol (JSON over WS)
----------------------------
Client -> server:
    {"type": "ping"}
    {"type": "typing", "is_typing": true|false}

Server -> client:
    {"type": "hello", "room_id": "...", "online": ["DOC1", "MUM2"]}
    {"type": "presence", "user_id": "DOC1", "user_type": "doctor", "online": true}
    {"type": "typing", "user_id": "DOC1", "user_type": "doctor", "is_typing": true}
    {"type": "message", "message": {...full message payload...}}
    {"type": "read", "user_id": "MUM2", "message_ids": [1, 2, 3]}
"""
from __future__ import annotations

import asyncio
import json
import logging
from collections import defaultdict
from datetime import datetime
from typing import Any, Iterable

from fastapi import WebSocket, WebSocketDisconnect

log = logging.getLogger(__name__)


class _Connection:
    __slots__ = ("ws", "user_id", "user_type")

    def __init__(self, ws: WebSocket, user_id: str, user_type: str) -> None:
        self.ws = ws
        self.user_id = user_id
        self.user_type = user_type


class ChatConnectionManager:
    """Tracks active WebSocket connections per room and fans out events."""

    def __init__(self) -> None:
        self._rooms: dict[str, list[_Connection]] = defaultdict(list)
        self._lock = asyncio.Lock()

    async def connect(self, room_id: str, user_id: str, user_type: str, websocket: WebSocket) -> None:
        await websocket.accept()
        conn = _Connection(websocket, user_id, user_type)
        async with self._lock:
            self._rooms[room_id].append(conn)
            online = list({(c.user_id, c.user_type) for c in self._rooms[room_id]})

        await self._safe_send(websocket, {
            "type": "hello",
            "room_id": room_id,
            "online": [{"user_id": uid, "user_type": ut} for uid, ut in online],
            "server_time": datetime.utcnow().isoformat(),
        })
        await self.broadcast(room_id, {
            "type": "presence",
            "user_id": user_id,
            "user_type": user_type,
            "online": True,
        }, exclude=websocket)

    async def disconnect(self, room_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            conns = self._rooms.get(room_id, [])
            removed: _Connection | None = None
            for c in conns:
                if c.ws is websocket:
                    removed = c
                    break
            if removed is not None:
                conns.remove(removed)
                if not conns:
                    self._rooms.pop(room_id, None)
        if removed is not None:
            await self.broadcast(room_id, {
                "type": "presence",
                "user_id": removed.user_id,
                "user_type": removed.user_type,
                "online": False,
            }, exclude=websocket)

    async def broadcast(
        self,
        room_id: str,
        payload: dict[str, Any],
        *,
        exclude: WebSocket | None = None,
    ) -> None:
        # Snapshot connections so we don't hold the lock while sending.
        async with self._lock:
            conns = list(self._rooms.get(room_id, []))
        if not conns:
            return
        await asyncio.gather(
            *[
                self._safe_send(c.ws, payload)
                for c in conns
                if exclude is None or c.ws is not exclude
            ],
            return_exceptions=True,
        )

    def broadcast_threadsafe(self, room_id: str, payload: dict[str, Any]) -> None:
        """Fire-and-forget broadcast that works from sync code (e.g. REST handlers).

        FastAPI's dependency-injected handlers may run in the threadpool. This
        helper schedules the broadcast onto the running event loop without
        blocking the caller.
        """
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            return
        if loop.is_closed():
            return
        # `asyncio.run_coroutine_threadsafe` is safe across thread boundaries.
        try:
            asyncio.run_coroutine_threadsafe(self.broadcast(room_id, payload), loop)
        except RuntimeError:
            # Loop not running (e.g. tests). Best-effort.
            asyncio.ensure_future(self.broadcast(room_id, payload))

    @staticmethod
    async def _safe_send(ws: WebSocket, payload: dict[str, Any]) -> None:
        try:
            await ws.send_text(json.dumps(payload))
        except Exception:  # noqa: BLE001 - swallow per-connection errors
            log.exception("chat ws send failed")


# Singleton used by the REST handler and the WS endpoint.
manager = ChatConnectionManager()


async def chat_websocket_endpoint(
    websocket: WebSocket,
    room_id: str,
    user_id: str,
    user_type: str,
) -> None:
    user_id = user_id.strip().upper()
    user_type = user_type.strip().lower()
    await manager.connect(room_id, user_id, user_type, websocket)
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue
            event_type = data.get("type")
            if event_type == "ping":
                await ChatConnectionManager._safe_send(websocket, {"type": "pong"})
            elif event_type == "typing":
                await manager.broadcast(
                    room_id,
                    {
                        "type": "typing",
                        "user_id": user_id,
                        "user_type": user_type,
                        "is_typing": bool(data.get("is_typing", False)),
                    },
                    exclude=websocket,
                )
            # Other client-originated events can be added here (read receipts, etc.)
    except WebSocketDisconnect:
        pass
    except Exception:  # noqa: BLE001
        log.exception("chat ws receive failed")
    finally:
        await manager.disconnect(room_id, websocket)


def serialize_message_for_broadcast(message: Any) -> dict[str, Any]:
    """Convert a ChatMessage ORM object to the broadcast JSON shape."""
    return {
        "id": message.id,
        "room_id": message.room_id,
        "sender_id": message.sender_id,
        "sender_type": message.sender_type,
        "message_text": message.message_text,
        "message_type": message.message_type,
        "file_url": message.file_url,
        "is_read": message.is_read,
        "created_at": message.created_at.isoformat() if message.created_at else None,
    }


def broadcast_new_message(room_id: str, message: Any) -> None:
    """Called from the REST handler immediately after committing a message."""
    manager.broadcast_threadsafe(
        room_id,
        {"type": "message", "message": serialize_message_for_broadcast(message)},
    )


def broadcast_messages_read(room_id: str, user_id: str, message_ids: Iterable[int]) -> None:
    manager.broadcast_threadsafe(
        room_id,
        {
            "type": "read",
            "user_id": user_id.strip().upper(),
            "message_ids": list(message_ids),
        },
    )
