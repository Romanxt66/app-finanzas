import time
from collections.abc import Iterator
from typing import Any

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from httpx import AsyncClient

from app.core import google
from app.core.config import get_settings
from tests.conftest import register_and_login

CLIENT_ID = "alvea-web.apps.googleusercontent.com"
_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)


class _FakeJwk:
    key = _key.public_key()


@pytest.fixture(autouse=True)
def _google(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Google «de mentira»: nuestras claves firman los tokens y no hay red."""
    monkeypatch.setattr(google._jwks, "get_signing_key_from_jwt", lambda _t: _FakeJwk())
    monkeypatch.setattr(get_settings(), "google_client_ids", [CLIENT_ID])
    yield


def token(**over: Any) -> str:
    now = int(time.time())
    claims = {
        "iss": "https://accounts.google.com",
        "aud": CLIENT_ID,
        "sub": "google-123",
        "email": "ana@example.com",
        "email_verified": True,
        "name": "Ana Gómez",
        "iat": now,
        "exp": now + 600,
        **over,
    }
    return jwt.encode(claims, _key, algorithm="RS256")


async def _login(client: AsyncClient, **over: Any) -> Any:
    return await client.post("/api/v1/auth/google", json={"id_token": token(**over)})


def _h(r: Any) -> dict[str, str]:
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


async def test_creates_account_without_password(client: AsyncClient) -> None:
    r = await _login(client)
    assert r.status_code == 200, r.text
    me = (await client.get("/api/v1/auth/me", headers=_h(r))).json()
    assert me["email"] == "ana@example.com"
    assert me["full_name"] == "Ana Gómez"
    assert me["email_login"] is False and me["google_linked"] is True
    # La misma cuenta de Google vuelve a entrar a la misma cuenta
    again = await _login(client, email="otro-correo@example.com")
    me2 = (await client.get("/api/v1/auth/me", headers=_h(again))).json()
    assert me2["id"] == me["id"]
    # Sin contraseña no se puede entrar por la vía normal
    bad = await client.post(
        "/api/v1/auth/login", json={"email": "ana@example.com", "password": "loquesea-1"}
    )
    assert bad.status_code == 401


async def test_links_existing_account_only_if_email_verified(client: AsyncClient) -> None:
    h = await register_and_login(client, "ana@example.com")
    await client.post(
        "/api/v1/accounts",
        headers=h,
        json={"name": "Caja", "type": "cash", "currency": "COP", "initial_balance": "0"},
    )
    unverified = await _login(client, email_verified=False)
    assert unverified.status_code == 401
    r = await _login(client)
    assert r.status_code == 200
    assert len((await client.get("/api/v1/accounts", headers=_h(r))).json()) == 1
    me = (await client.get("/api/v1/auth/me", headers=_h(r))).json()
    assert me["email_login"] is True and me["google_linked"] is True


@pytest.mark.parametrize(
    "over",
    [
        {"aud": "otra-app.apps.googleusercontent.com"},
        {"iss": "https://evil.example.com"},
        {"exp": int(time.time()) - 3600, "iat": int(time.time()) - 7200},
    ],
)
async def test_rejects_tokens_not_for_us(client: AsyncClient, over: dict[str, Any]) -> None:
    assert (await _login(client, **over)).status_code == 401


async def test_rejects_tokens_signed_by_someone_else(client: AsyncClient) -> None:
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    now = int(time.time())
    forged = jwt.encode(
        {
            "iss": "accounts.google.com",
            "aud": CLIENT_ID,
            "sub": "x",
            "email": "a@b.co",
            "iat": now,
            "exp": now + 60,
        },
        other,
        algorithm="RS256",
    )
    r = await client.post("/api/v1/auth/google", json={"id_token": forged})
    assert r.status_code == 401


async def test_disabled_without_client_ids(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(get_settings(), "google_client_ids", [])
    assert (await _login(client)).status_code == 400


async def test_google_account_can_create_a_password(client: AsyncClient) -> None:
    h = _h(await _login(client))
    r = await client.post(
        "/api/v1/auth/change-password", headers=h, json={"new_password": "nueva-clave-1"}
    )
    assert r.status_code == 200, r.text
    ok = await client.post(
        "/api/v1/auth/login", json={"email": "ana@example.com", "password": "nueva-clave-1"}
    )
    assert ok.status_code == 200
    # Con contraseña ya creada, cambiarla exige la actual
    h2 = {"Authorization": f"Bearer {r.json()['access_token']}"}
    again = await client.post(
        "/api/v1/auth/change-password", headers=h2, json={"new_password": "otra-clave-2"}
    )
    assert again.status_code == 400


async def test_google_only_account_deletes_by_confirming_with_google(client: AsyncClient) -> None:
    h = _h(await _login(client))
    wrong = await client.request(
        "DELETE", "/api/v1/auth/me", headers=h, json={"google_id_token": token(sub="otra")}
    )
    assert wrong.status_code == 400
    assert (
        await client.request("DELETE", "/api/v1/auth/me", headers=h, json={})
    ).status_code == 400
    ok = await client.request(
        "DELETE", "/api/v1/auth/me", headers=h, json={"google_id_token": token()}
    )
    assert ok.status_code == 204
    assert (await client.get("/api/v1/auth/me", headers=h)).status_code == 401
