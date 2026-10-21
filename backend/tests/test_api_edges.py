from httpx import AsyncClient

from tests.conftest import register_and_login


async def test_health(client: AsyncClient) -> None:
    assert (await client.get("/health")).json() == {"status": "ok"}


async def test_validation_error_format(client: AsyncClient) -> None:
    resp = await client.post("/api/v1/auth/register", json={"email": "no-email"})
    assert resp.status_code == 422
    body = resp.json()["error"]
    assert body["code"] == "validation_error" and body["details"]


async def test_short_password_rejected(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/v1/auth/register",
        json={"email": "a@example.com", "password": "corta", "full_name": "A"},
    )
    assert resp.status_code == 422


async def test_invalid_and_missing_token(client: AsyncClient) -> None:
    bad = await client.get("/api/v1/auth/me", headers={"Authorization": "Bearer basura"})
    assert bad.status_code == 401 and bad.json()["error"]["code"] == "unauthorized"
    assert (await client.get("/api/v1/auth/me")).status_code == 401


async def test_refresh_token_cannot_access_resources(client: AsyncClient) -> None:
    await register_and_login(client)
    tokens = (
        await client.post(
            "/api/v1/auth/login", json={"email": "a@example.com", "password": "password-123"}
        )
    ).json()
    resp = await client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {tokens['refresh_token']}"}
    )
    assert resp.status_code == 401


async def test_password_never_in_responses(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/v1/auth/register",
        json={"email": "a@example.com", "password": "password-123", "full_name": "A"},
    )
    assert "password" not in resp.text


async def test_unknown_ids_return_404(client: AsyncClient, auth: dict[str, str]) -> None:
    missing = "00000000-0000-0000-0000-000000000000"
    for path in ("accounts", "transactions"):
        assert (await client.get(f"/api/v1/{path}/{missing}", headers=auth)).status_code == 404
    assert (await client.delete(f"/api/v1/budgets/{missing}", headers=auth)).status_code == 404
    assert (await client.get("/api/v1/accounts/no-uuid", headers=auth)).status_code == 422


async def test_pagination_limits_validated(client: AsyncClient, auth: dict[str, str]) -> None:
    assert (await client.get("/api/v1/transactions?limit=0", headers=auth)).status_code == 422
    assert (await client.get("/api/v1/transactions?limit=500", headers=auth)).status_code == 422
    assert (await client.get("/api/v1/transactions?offset=-1", headers=auth)).status_code == 422


async def test_cors_only_for_configured_origins(client: AsyncClient) -> None:
    resp = await client.options(
        "/health",
        headers={"Origin": "http://evil.example", "Access-Control-Request-Method": "GET"},
    )
    assert "access-control-allow-origin" not in resp.headers


async def test_openapi_exposes_all_routers(client: AsyncClient) -> None:
    paths = (await client.get("/openapi.json")).json()["paths"]
    for prefix in ("auth", "accounts", "categories", "transactions", "budgets", "reports"):
        assert any(p.startswith(f"/api/v1/{prefix}") for p in paths)


async def _register(client: AsyncClient, password: str) -> dict[str, object]:
    resp = await client.post(
        "/api/v1/auth/register",
        json={"email": "p@example.com", "password": password, "full_name": "P"},
    )
    assert resp.status_code == 422, resp.text
    return dict(resp.json()["error"])


async def test_password_errors_explain_the_reason(client: AsyncClient) -> None:
    cases = {
        "corta1": "al menos 8 caracteres",
        "soloLetrasAqui": "al menos un número",
        "1234567890": "al menos una letra",
        "a1" * 70: "no puede superar 128",
    }
    for password, reason in cases.items():
        error = await _register(client, password)
        assert reason in str(error["message"]), (password[:10], error)
        assert error["code"] == "validation_error"
        details = error["details"]
        assert isinstance(details, list) and details[0]["field"] == "password"


async def test_validation_messages_are_in_spanish(client: AsyncClient) -> None:
    resp = await client.post("/api/v1/auth/register", json={"email": "no-email", "full_name": ""})
    messages = {d["field"]: d["msg"] for d in resp.json()["error"]["details"]}
    assert messages["email"] == "Correo electrónico inválido"
    assert messages["password"] == "Campo requerido"
    assert "al menos 1 caracteres" in messages["full_name"]


async def test_valid_password_is_accepted(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/v1/auth/register",
        json={"email": "ok@example.com", "password": "Clave-segura-2026", "full_name": "Ok"},
    )
    assert resp.status_code == 201
