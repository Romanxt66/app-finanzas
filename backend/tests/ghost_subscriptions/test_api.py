from httpx import AsyncClient

from tests.conftest import register_and_login

H = dict[str, str]
URL = "/api/v1/ghost-subscriptions"


async def _account(c: AsyncClient, h: H) -> str:
    r = await c.post(
        "/api/v1/accounts",
        headers=h,
        json={"name": "Banco", "type": "bank", "currency": "EUR", "initial_balance": "0"},
    )
    return str(r.json()["id"])


async def _expense(c: AsyncClient, h: H, account: str, description: str, day: str) -> None:
    r = await c.post(
        "/api/v1/transactions",
        headers=h,
        json={
            "type": "expense",
            "account_id": account,
            "amount": "10.99",
            "description": description,
            "occurred_on": day,
        },
    )
    assert r.status_code == 201, r.text


DAYS = ["2026-07-05", "2026-08-05", "2026-09-05", "2026-10-05"]


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401


async def test_empty_report(client: AsyncClient, auth: H) -> None:
    r = await client.get(URL, headers=auth, params={"today": "2026-10-21"})
    assert r.status_code == 200
    assert r.json() == {"subscriptions": [], "alerts": [], "untracked_monthly": []}


async def test_detects_ghost_then_tracked_by_recurring_rule(client: AsyncClient, auth: H) -> None:
    account = await _account(client, auth)
    for day in DAYS:
        await _expense(client, auth, account, "Netflix", day)

    body = (await client.get(URL, headers=auth, params={"today": "2026-10-21"})).json()
    [sub] = body["subscriptions"]
    assert sub["name"] == "Netflix"
    assert sub["tracked"] is False
    assert sub["monthly_cost"] == "10.99"
    assert body["untracked_monthly"] == [{"currency": "EUR", "total": "10.99"}]

    rule = await client.post(
        "/api/v1/recurring",
        headers=auth,
        json={
            "type": "expense",
            "account_id": account,
            "amount": "10.99",
            "description": "Netflix",
            "frequency": "monthly",
            "start_date": "2026-11-05",
        },
    )
    assert rule.status_code == 201, rule.text
    body = (await client.get(URL, headers=auth, params={"today": "2026-10-21"})).json()
    assert body["subscriptions"][0]["tracked"] is True
    assert body["untracked_monthly"] == []


async def test_other_users_data_is_invisible(client: AsyncClient, auth: H) -> None:
    account = await _account(client, auth)
    for day in DAYS:
        await _expense(client, auth, account, "Netflix", day)
    other = await register_and_login(client, "b@example.com")
    body = (await client.get(URL, headers=other, params={"today": "2026-10-21"})).json()
    assert body["subscriptions"] == []
