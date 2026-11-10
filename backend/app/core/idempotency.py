"""Escrituras idempotentes con la cabecera `Idempotency-Key`.

La app Android guarda los cambios hechos sin conexión y los reenvía al volver la señal. Si un envío
llegó al servidor pero se perdió la respuesta, el reenvío lleva la misma clave: aquí se devuelve la
respuesta guardada sin aplicar el cambio otra vez (no hay movimientos duplicados).
"""

import json
import re
import uuid
from collections.abc import AsyncIterator, Awaitable, Callable, MutableMapping
from datetime import UTC, datetime, timedelta
from typing import Any, cast

from sqlalchemy import delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import UnauthorizedError
from app.core.security import decode_token
from app.db.session import get_session
from app.models.idempotency import IdempotencyRecord

Scope = MutableMapping[str, Any]
Message = MutableMapping[str, Any]
Receive = Callable[[], Awaitable[Message]]
Send = Callable[[Message], Awaitable[None]]
ASGIApp = Callable[[Scope, Receive, Send], Awaitable[None]]

_WRITES = {"POST", "PUT", "PATCH", "DELETE"}
_KEY = re.compile(r"^[A-Za-z0-9_-]{8,100}$")
_KEEP = timedelta(days=3)
_MAX_BODY = 64 * 1024


def _header(scope: Scope, name: bytes) -> str | None:
    for k, v in scope.get("headers", []):
        if k.lower() == name:
            return cast(bytes, v).decode("latin-1")
    return None


def _user_id(scope: Scope) -> uuid.UUID | None:
    auth = _header(scope, b"authorization") or ""
    if not auth.lower().startswith("bearer "):
        return None
    try:
        return decode_token(auth[7:].strip(), "access").user_id
    except UnauthorizedError:
        return None


async def _json(send: Send, status: int, body: bytes, extra: list[tuple[bytes, bytes]]) -> None:
    headers = [(b"content-length", str(len(body)).encode()), *extra]
    if body:
        headers.append((b"content-type", b"application/json"))
    await send({"type": "http.response.start", "status": status, "headers": headers})
    await send({"type": "http.response.body", "body": body})


class IdempotencyMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def _session(self, scope: Scope) -> AsyncIterator[AsyncSession]:
        # La misma sesión que usan las rutas (las pruebas la sustituyen por una base en memoria)
        overrides: dict[Any, Any] = getattr(scope.get("app"), "dependency_overrides", {})
        factory = overrides.get(get_session, get_session)
        async for session in factory():
            yield session

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope["method"] not in _WRITES:
            await self.app(scope, receive, send)
            return
        key = _header(scope, b"idempotency-key")
        user_id = _user_id(scope) if key and _KEY.match(key) else None
        if key is None or user_id is None:
            await self.app(scope, receive, send)
            return

        method, path = scope["method"], scope["path"]
        async for session in self._session(scope):
            saved = await session.get(IdempotencyRecord, (user_id, key))
            if saved is not None:
                if saved.method != method or saved.path != path:
                    body = json.dumps(
                        {
                            "error": {
                                "code": "idempotency_conflict",
                                "message": "Esa clave de envío ya se usó para otro cambio.",
                            }
                        }
                    ).encode()
                    await _json(send, 409, body, [])
                    return
                await _json(
                    send,
                    saved.status_code,
                    saved.body.encode(),
                    [(b"idempotent-replayed", b"true")],
                )
                return

        status = 0
        chunks: list[bytes] = []

        async def capture(message: Message) -> None:
            nonlocal status
            if message["type"] == "http.response.start":
                status = int(message["status"])
            elif message["type"] == "http.response.body":
                chunks.append(cast(bytes, message.get("body", b"")))
            await send(message)

        await self.app(scope, receive, capture)

        body = b"".join(chunks)
        # Solo se recuerdan los éxitos: un error (validación, BD caída…) se puede reintentar
        if not 200 <= status < 300 or len(body) > _MAX_BODY:
            return
        async for session in self._session(scope):
            await session.execute(
                delete(IdempotencyRecord).where(
                    IdempotencyRecord.created_at < datetime.now(UTC) - _KEEP
                )
            )
            session.add(
                IdempotencyRecord(
                    user_id=user_id,
                    key=key,
                    method=method,
                    path=path,
                    status_code=status,
                    body=body.decode("utf-8", errors="replace"),
                )
            )
            try:
                await session.commit()
            except IntegrityError:  # dos envíos simultáneos con la misma clave: basta con uno
                await session.rollback()
