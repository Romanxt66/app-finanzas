from unittest.mock import patch

from httpx import AsyncClient

from app.core import totp
from tests.conftest import register_and_login

LOGIN = {"email": "a@example.com", "password": "password-123"}


def test_totp_matches_rfc6238_vector() -> None:
    # Vector de prueba del RFC 6238 (SHA-1, T = 59 s) recortado a 6 dígitos
    secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"  # "12345678901234567890" en base32
    assert totp.code_at(secret, 59 // 30) == "287082"
    assert totp.matching_step(secret, "287 082", now=59) == 1
    assert totp.matching_step(secret, "000000", now=59) is None


async def _enable(client: AsyncClient, headers: dict[str, str]) -> tuple[str, list[str]]:
    setup = await client.post("/api/v1/auth/2fa/setup", headers=headers)
    assert setup.status_code == 200
    secret = setup.json()["secret"]
    assert setup.json()["otpauth_uri"].startswith("otpauth://totp/Alvea%3Aa%40example.com?")
    bad = await client.post("/api/v1/auth/2fa/enable", headers=headers, json={"code": "000000"})
    assert bad.status_code == 400
    code = totp.code_at(secret, totp.current_step())
    ok = await client.post("/api/v1/auth/2fa/enable", headers=headers, json={"code": code})
    assert ok.status_code == 200
    return secret, ok.json()["recovery_codes"]


async def test_login_requires_code_once_enabled(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    me = await client.get("/api/v1/auth/me", headers=headers)
    assert me.json()["two_factor_enabled"] is False
    secret, codes = await _enable(client, headers)
    assert len(codes) == 8
    me = await client.get("/api/v1/auth/me", headers=headers)
    assert me.json()["two_factor_enabled"] is True

    missing = await client.post("/api/v1/auth/login", json=LOGIN)
    assert missing.status_code == 401
    assert missing.json()["error"]["code"] == "otp_required"

    wrong = await client.post("/api/v1/auth/login", json={**LOGIN, "otp": "000000"})
    assert wrong.status_code == 401
    assert wrong.json()["error"]["code"] == "unauthorized"

    # Un código del siguiente paso (el usado al activar ya no vale)
    next_code = totp.code_at(secret, totp.current_step() + 1)
    good = await client.post("/api/v1/auth/login", json={**LOGIN, "otp": next_code})
    assert good.status_code == 200
    replay = await client.post("/api/v1/auth/login", json={**LOGIN, "otp": next_code})
    assert replay.status_code == 401


async def test_recovery_code_works_once(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    _, codes = await _enable(client, headers)
    first = await client.post("/api/v1/auth/login", json={**LOGIN, "otp": codes[0].upper()})
    assert first.status_code == 200
    again = await client.post("/api/v1/auth/login", json={**LOGIN, "otp": codes[0]})
    assert again.status_code == 401


async def test_wrong_password_never_reveals_two_factor(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    await _enable(client, headers)
    resp = await client.post(
        "/api/v1/auth/login", json={"email": LOGIN["email"], "password": "nope-12345"}
    )
    assert resp.json()["error"]["code"] == "unauthorized"


async def test_disable_needs_password_and_code(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    secret, _ = await _enable(client, headers)
    later = totp.current_step() + 1
    with patch("app.core.totp.current_step", return_value=later):
        code = totp.code_at(secret, later)
        bad = await client.post(
            "/api/v1/auth/2fa/disable", headers=headers, json={"password": "x", "code": code}
        )
        assert bad.status_code == 400
        ok = await client.post(
            "/api/v1/auth/2fa/disable",
            headers=headers,
            json={"password": "password-123", "code": code},
        )
        assert ok.status_code == 204
    login = await client.post("/api/v1/auth/login", json=LOGIN)
    assert login.status_code == 200


async def test_setup_twice_conflicts_once_enabled(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    await _enable(client, headers)
    resp = await client.post("/api/v1/auth/2fa/setup", headers=headers)
    assert resp.status_code == 409


async def test_regenerate_recovery_codes(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    _, old = await _enable(client, headers)
    resp = await client.post(
        "/api/v1/auth/2fa/recovery-codes", headers=headers, json={"code": old[0]}
    )
    assert resp.status_code == 200
    new = resp.json()["recovery_codes"]
    stale = await client.post("/api/v1/auth/login", json={**LOGIN, "otp": old[1]})
    assert stale.status_code == 401
    fresh = await client.post("/api/v1/auth/login", json={**LOGIN, "otp": new[0]})
    assert fresh.status_code == 200
