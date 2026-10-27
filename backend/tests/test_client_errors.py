import logging

import pytest
from httpx import AsyncClient

URL = "/api/v1/client-errors"


async def test_logs_without_secrets(client: AsyncClient, caplog: pytest.LogCaptureFixture) -> None:
    caplog.set_level(logging.WARNING, logger="app.client")
    r = await client.post(
        URL,
        json={
            "message": "TypeError for ana@example.com with Bearer abc.def",
            "stack": "at main.dart.js:1\ntoken eyJhbGciOi.eyJzdWIiOi.c2lnbmF0dXJl",
            "route": "/accounts?token=secret",
            "release": "1.0.0",
            "platform": "web",
        },
    )
    assert r.status_code == 204
    text = caplog.text
    assert "route=/accounts " in text and "secret" not in text
    assert "ana@example.com" not in text and "eyJhbGciOi" not in text and "abc.def" not in text
    assert "TypeError for [redacted]" in text


async def test_rate_limited_per_ip(client: AsyncClient, caplog: pytest.LogCaptureFixture) -> None:
    caplog.set_level(logging.WARNING, logger="app.client")
    for _ in range(35):
        r = await client.post(URL, json={"message": "boom"})
        assert r.status_code == 204
    assert caplog.text.count("client error") == 30


async def test_rejects_oversized_reports(client: AsyncClient) -> None:
    r = await client.post(URL, json={"message": "x" * 1001})
    assert r.status_code == 422
