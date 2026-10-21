import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.config import get_settings
from app.core.errors import UnauthorizedError
from app.core.security import create_token, decode_token, hash_password, verify_password


def test_password_hash_is_salted_and_verifiable() -> None:
    h1, h2 = hash_password("password-123"), hash_password("password-123")
    assert h1 != h2 and "password-123" not in h1
    assert verify_password("password-123", h1)
    assert not verify_password("otra-clave", h1)


def test_token_roundtrip() -> None:
    uid = uuid.uuid4()
    claims = decode_token(create_token(uid, "access", 3), "access")
    assert (claims.user_id, claims.version) == (uid, 3)


def test_token_type_is_enforced() -> None:
    token = create_token(uuid.uuid4(), "refresh")
    with pytest.raises(UnauthorizedError):
        decode_token(token, "access")


def test_expired_token_rejected() -> None:
    payload = {"sub": str(uuid.uuid4()), "type": "access", "exp": datetime.now(UTC) - timedelta(1)}
    token = jwt.encode(payload, get_settings().secret_key, algorithm="HS256")
    with pytest.raises(UnauthorizedError):
        decode_token(token, "access")


def test_token_signed_with_other_key_rejected() -> None:
    payload = {"sub": str(uuid.uuid4()), "type": "access"}
    token = jwt.encode(payload, "x" * 40, algorithm="HS256")
    with pytest.raises(UnauthorizedError):
        decode_token(token, "access")


def test_malformed_subject_rejected() -> None:
    token = jwt.encode(
        {"sub": "no-es-uuid", "type": "access"}, get_settings().secret_key, algorithm="HS256"
    )
    with pytest.raises(UnauthorizedError):
        decode_token(token, "access")


def test_settings_require_long_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    from pydantic import ValidationError

    from app.core.config import Settings

    monkeypatch.setenv("SECRET_KEY", "corta")
    with pytest.raises(ValidationError):
        Settings()  # type: ignore[call-arg]
