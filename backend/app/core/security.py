import uuid
from datetime import UTC, datetime, timedelta
from typing import Literal

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.core.config import get_settings
from app.core.errors import UnauthorizedError

_hasher = PasswordHasher()
TokenType = Literal["access", "refresh"]
_ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    try:
        return _hasher.verify(hashed, password)
    except VerifyMismatchError:
        return False


def create_token(user_id: uuid.UUID, token_type: TokenType) -> str:
    settings = get_settings()
    delta = (
        timedelta(minutes=settings.access_token_minutes)
        if token_type == "access"
        else timedelta(days=settings.refresh_token_days)
    )
    payload = {"sub": str(user_id), "type": token_type, "exp": datetime.now(UTC) + delta}
    return jwt.encode(payload, settings.secret_key, algorithm=_ALGORITHM)


def decode_token(token: str, expected: TokenType) -> uuid.UUID:
    try:
        payload = jwt.decode(token, get_settings().secret_key, algorithms=[_ALGORITHM])
        if payload.get("type") != expected:
            raise UnauthorizedError("Tipo de token inválido")
        return uuid.UUID(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError) as exc:
        raise UnauthorizedError("Token inválido o expirado") from exc
