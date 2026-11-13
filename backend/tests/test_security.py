import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.core.config import get_settings
from app.core.errors import UnauthorizedError
from app.core.security import create_token, decode_token, hash_password, verify_password
from tests.conftest import register_and_login


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


async def test_cambiar_contrasena_con_la_actual_mal_se_bloquea_tras_5_intentos(
    client: AsyncClient,
) -> None:
    headers = await register_and_login(client, "limite@example.com")
    body = {"current_password": "no-es-esta-1", "new_password": "otra-clave-123"}
    for _ in range(5):
        r = await client.post("/api/v1/auth/change-password", headers=headers, json=body)
        assert r.status_code == 400
    blocked = await client.post("/api/v1/auth/change-password", headers=headers, json=body)
    assert blocked.status_code == 429
    # Ni siquiera la contraseña correcta pasa mientras dure el bloqueo
    ok = {"current_password": "password-123", "new_password": "otra-clave-123"}
    assert (
        await client.post("/api/v1/auth/change-password", headers=headers, json=ok)
    ).status_code == 429


async def test_la_documentacion_no_se_publica_en_produccion(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from httpx import ASGITransport

    from app.core.config import get_settings
    from app.main import create_app

    monkeypatch.setenv("ENVIRONMENT", "production")
    get_settings.cache_clear()
    try:
        app = create_app()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as c:
            for path in ("/docs", "/redoc", "/openapi.json"):
                assert (await c.get(path)).status_code == 404
    finally:
        get_settings.cache_clear()


async def test_altas_limitadas_por_conexion(client: AsyncClient) -> None:
    for i in range(30):
        r = await client.post(
            "/api/v1/auth/register",
            json={"email": f"masa{i}@example.com", "password": "password-123", "full_name": "M"},
        )
        assert r.status_code == 201
    r = await client.post(
        "/api/v1/auth/register",
        json={"email": "masa-x@example.com", "password": "password-123", "full_name": "M"},
    )
    assert r.status_code == 429


async def test_hash_debil_se_renueva_al_entrar(client: AsyncClient, engine: AsyncEngine) -> None:
    from argon2 import PasswordHasher
    from sqlalchemy import select, update

    from app.core.security import needs_rehash
    from app.models import User

    await register_and_login(client)
    weak = PasswordHasher(time_cost=1, memory_cost=8192).hash("password-123")
    async with AsyncSession(engine) as s:
        await s.execute(update(User).values(hashed_password=weak))
        await s.commit()
    r = await client.post(
        "/api/v1/auth/login", json={"email": "a@example.com", "password": "password-123"}
    )
    assert r.status_code == 200
    async with AsyncSession(engine) as s:
        stored = await s.scalar(select(User.hashed_password))
    assert stored is not None and stored != weak and not needs_rehash(stored)


def test_hash_danado_no_entra_ni_falla() -> None:
    assert verify_password("lo-que-sea", "esto-no-es-un-hash") is False
