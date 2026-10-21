from httpx import AsyncClient

from tests.conftest import register_and_login


async def test_register_login_me(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    resp = await client.get("/api/v1/auth/me", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["email"] == "a@example.com"


async def test_duplicate_email_conflict(client: AsyncClient) -> None:
    await register_and_login(client)
    resp = await client.post(
        "/api/v1/auth/register",
        json={"email": "A@example.com", "password": "password-123", "full_name": "X"},
    )
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "conflict"


async def test_wrong_password(client: AsyncClient) -> None:
    await register_and_login(client)
    resp = await client.post(
        "/api/v1/auth/login", json={"email": "a@example.com", "password": "nope-nope"}
    )
    assert resp.status_code == 401


async def test_refresh_and_token_type(client: AsyncClient) -> None:
    await register_and_login(client)
    tokens = (
        await client.post(
            "/api/v1/auth/login", json={"email": "a@example.com", "password": "password-123"}
        )
    ).json()
    ok = await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert ok.status_code == 200
    bad = await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["access_token"]})
    assert bad.status_code == 401


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get("/api/v1/accounts")).status_code == 401
