import logging

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import create_app


async def test_every_response_has_a_unique_request_id(client: AsyncClient) -> None:
    a = (await client.get("/health")).headers["x-request-id"]
    b = (await client.get("/health")).headers["x-request-id"]
    assert a != b and len(a) >= 8


async def test_valid_incoming_id_is_kept_and_unsafe_one_is_replaced(client: AsyncClient) -> None:
    kept = await client.get("/health", headers={"X-Request-ID": "trace-abc-12345"})
    assert kept.headers["x-request-id"] == "trace-abc-12345"
    for bad in ("corto", "con espacios y <tags>", "x" * 200, "id\nsplit"):
        try:
            resp = await client.get("/health", headers={"X-Request-ID": bad})
        except Exception:  # httpx rechaza algunos valores antes de enviarlos
            continue
        assert resp.headers["x-request-id"] != bad


async def test_access_log_has_method_path_status_and_no_query_or_secrets(
    client: AsyncClient, caplog: pytest.LogCaptureFixture
) -> None:
    caplog.set_level(logging.INFO, logger="app.access")
    await client.get(
        "/api/v1/transactions?search=secreto-personal",
        headers={"Authorization": "Bearer token-super-secreto"},
    )
    line = next(r.getMessage() for r in caplog.records if r.name == "app.access")
    assert "GET /api/v1/transactions -> 401" in line
    assert "secreto" not in line and "token" not in line.lower().replace("request_id", "")


async def test_unhandled_exception_returns_uniform_500_with_request_id(
    caplog: pytest.LogCaptureFixture,
) -> None:
    app = create_app()

    @app.get("/boom")
    async def boom() -> None:
        raise RuntimeError("detalle interno que no debe filtrarse")

    caplog.set_level(logging.ERROR, logger="app.error")
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as c:
        resp = await c.get("/boom")
    body = resp.json()["error"]
    assert resp.status_code == 500 and body["code"] == "internal_error"
    assert body["request_id"] == resp.headers["x-request-id"]
    assert "detalle interno" not in resp.text  # el cliente no ve el motivo…
    assert any("detalle interno" in (r.exc_text or "") for r in caplog.records)  # …el log sí
