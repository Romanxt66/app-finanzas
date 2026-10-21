from decimal import Decimal

from httpx import AsyncClient

from app.services.life_hours import hourly_rate, to_hours
from tests.conftest import register_and_login

H = dict[str, str]
PROFILE = {"monthly_net_income": "2000.00", "weekly_hours": "40"}


def test_hourly_rate_uses_exact_decimals() -> None:
    # 40 h/semana * 52 / 12 = 173.33... h/mes
    assert hourly_rate(Decimal("2000"), Decimal("40")) == Decimal("11.54")
    assert to_hours(Decimal("23.08"), Decimal("11.54")) == Decimal("2.00")


async def test_profile_required_before_use(client: AsyncClient, auth: H) -> None:
    assert (await client.get("/api/v1/life-hours/profile", headers=auth)).status_code == 404
    r = await client.get("/api/v1/life-hours/convert", headers=auth, params={"amount": "10"})
    assert r.status_code == 404


async def test_profile_upsert_and_convert(client: AsyncClient, auth: H) -> None:
    r = await client.put("/api/v1/life-hours/profile", headers=auth, json=PROFILE)
    assert r.status_code == 200, r.text
    assert r.json()["hourly_rate"] == "11.54"

    r = await client.put(
        "/api/v1/life-hours/profile",
        headers=auth,
        json={"monthly_net_income": "3000.00", "weekly_hours": "30"},
    )
    assert r.json()["hourly_rate"] == "23.08"

    r = await client.get("/api/v1/life-hours/convert", headers=auth, params={"amount": "46.16"})
    assert r.json()["hours"] == "2.00"


async def test_profile_validation(client: AsyncClient, auth: H) -> None:
    for body in (
        {"monthly_net_income": "0", "weekly_hours": "40"},
        {"monthly_net_income": "2000", "weekly_hours": "0"},
        {"monthly_net_income": "2000", "weekly_hours": "169"},
    ):
        r = await client.put("/api/v1/life-hours/profile", headers=auth, json=body)
        assert r.status_code == 422


async def test_month_summary_and_isolation(client: AsyncClient, auth: H) -> None:
    await client.put("/api/v1/life-hours/profile", headers=auth, json=PROFILE)
    acc = (
        await client.post(
            "/api/v1/accounts",
            headers=auth,
            json={"name": "Banco", "type": "bank", "currency": "usd", "initial_balance": "0"},
        )
    ).json()["id"]
    cat = (
        await client.post(
            "/api/v1/categories", headers=auth, json={"name": "Comida", "kind": "expense"}
        )
    ).json()["id"]
    for amount, day in (("11.54", "2026-03-05"), ("23.08", "2026-03-20"), ("99", "2026-04-01")):
        await client.post(
            "/api/v1/transactions",
            headers=auth,
            json={
                "account_id": acc,
                "category_id": cat,
                "type": "expense",
                "amount": amount,
                "occurred_on": day,
            },
        )

    r = await client.get("/api/v1/life-hours/summary", headers=auth, params={"month": "2026-03-15"})
    body = r.json()
    assert body["total"] == "34.62"
    assert body["total_hours"] == "3.00"
    assert body["by_category"][0]["category_id"] == cat

    other = await register_and_login(client, "b@example.com")
    assert (await client.get("/api/v1/life-hours/profile", headers=other)).status_code == 404
