from httpx import AsyncClient

from app.core.currencies import SUPPORTED_CURRENCIES
from tests.conftest import register_and_login

H = dict[str, str]


async def test_lists_supported_currencies(client: AsyncClient) -> None:
    r = await client.get("/api/v1/currencies")
    assert r.status_code == 200
    assert r.json() == list(SUPPORTED_CURRENCIES)
    assert len(set(r.json())) == len(r.json())


async def test_account_accepts_any_supported_currency(client: AsyncClient, auth: H) -> None:
    for code in ("eur", "JPY", "mxn"):
        r = await client.post(
            "/api/v1/accounts",
            headers=auth,
            json={"name": code, "type": "bank", "currency": code, "initial_balance": "0"},
        )
        assert r.status_code == 201, r.text
        assert r.json()["currency"] == code.upper()


async def test_account_rejects_unsupported_currency(client: AsyncClient) -> None:
    auth = await register_and_login(client)
    r = await client.post(
        "/api/v1/accounts",
        headers=auth,
        json={"name": "X", "type": "bank", "currency": "ZZZ", "initial_balance": "0"},
    )
    assert r.status_code == 422
