from datetime import date

import pytest
from httpx import AsyncClient

from app.models import Frequency, RecurringRule
from app.services.recurring import advance
from tests.conftest import register_and_login

H = dict[str, str]


async def _mk(c: AsyncClient, h: H, path: str, body: dict[str, object]) -> dict[str, str]:
    r = await c.post(f"/api/v1/{path}", headers=h, json=body)
    assert r.status_code == 201, r.text
    return dict(r.json())


async def _setup(c: AsyncClient, h: H) -> dict[str, str]:
    acc = await _mk(
        c,
        h,
        "accounts",
        {"name": "Caja", "type": "bank", "currency": "COP", "initial_balance": "0"},
    )
    cat = await _mk(c, h, "categories", {"name": "Arriendo", "kind": "expense"})
    return {"account": acc["id"], "category": cat["id"]}


def _rule(ids: dict[str, str], **over: object) -> dict[str, object]:
    return {
        "type": "expense",
        "account_id": ids["account"],
        "category_id": ids["category"],
        "amount": "800000",
        "description": "Arriendo",
        "frequency": "monthly",
        "start_date": "2026-01-31",
        **over,
    }


def _r(frequency: Frequency, next_date: date, anchor: date) -> RecurringRule:
    return RecurringRule(
        frequency=frequency, next_date=next_date, anchor_day=anchor.day, anchor_month=anchor.month
    )


# ---- cálculo de fechas ------------------------------------------------------
def test_monthly_keeps_anchor_day_across_short_months() -> None:
    anchor = date(2026, 1, 31)
    d = anchor
    seen = []
    for _ in range(4):
        d = advance(_r(Frequency.monthly, d, anchor))
        seen.append(d)
    assert seen == [date(2026, 2, 28), date(2026, 3, 31), date(2026, 4, 30), date(2026, 5, 31)]


def test_monthly_crosses_year_and_leap_february() -> None:
    assert advance(_r(Frequency.monthly, date(2026, 12, 15), date(2026, 12, 15))) == date(
        2027, 1, 15
    )
    assert advance(_r(Frequency.monthly, date(2028, 1, 30), date(2028, 1, 30))) == date(2028, 2, 29)


def test_weekly_and_yearly() -> None:
    assert advance(_r(Frequency.weekly, date(2026, 12, 28), date(2026, 12, 28))) == date(2027, 1, 4)
    assert advance(_r(Frequency.yearly, date(2028, 2, 29), date(2028, 2, 29))) == date(2029, 2, 28)
    assert advance(_r(Frequency.yearly, date(2029, 2, 28), date(2028, 2, 29))) == date(2030, 2, 28)


# ---- API --------------------------------------------------------------------
async def test_run_creates_overdue_and_is_idempotent(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    await _mk(client, auth, "recurring", _rule(ids))
    first = await client.post("/api/v1/recurring/run?today=2026-04-15", headers=auth)
    assert first.json() == {"created": 3}  # 31 ene, 28 feb, 31 mar
    again = await client.post("/api/v1/recurring/run?today=2026-04-15", headers=auth)
    assert again.json() == {"created": 0}
    txs = (await client.get("/api/v1/transactions?limit=10", headers=auth)).json()["items"]
    assert sorted(t["occurred_on"] for t in txs) == ["2026-01-31", "2026-02-28", "2026-03-31"]
    assert all(t["description"] == "Arriendo" and t["amount"] == "800000.00" for t in txs)
    rule = (await client.get("/api/v1/recurring", headers=auth)).json()[0]
    assert rule["next_date"] == "2026-04-30"
    # el saldo refleja los movimientos creados
    acc = (await client.get("/api/v1/accounts", headers=auth)).json()[0]
    assert acc["balance"] == "-2400000.00"
    later = await client.post("/api/v1/recurring/run?today=2026-04-30", headers=auth)
    assert later.json() == {"created": 1}


async def test_future_start_creates_nothing(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    await _mk(client, auth, "recurring", _rule(ids, start_date="2099-01-01"))
    assert (await client.post("/api/v1/recurring/run", headers=auth)).json() == {"created": 0}


async def test_end_date_deactivates_rule(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    await _mk(client, auth, "recurring", _rule(ids, start_date="2026-01-10", end_date="2026-02-20"))
    res = await client.post("/api/v1/recurring/run?today=2026-06-01", headers=auth)
    assert res.json() == {"created": 2}  # 10 ene y 10 feb; 10 mar ya pasa de la fecha final
    rule = (await client.get("/api/v1/recurring", headers=auth)).json()[0]
    assert rule["active"] is False


async def test_inactive_rule_is_skipped_and_can_be_reactivated(
    client: AsyncClient, auth: H
) -> None:
    ids = await _setup(client, auth)
    rule = await _mk(client, auth, "recurring", _rule(ids, start_date="2026-01-01"))
    await client.patch(f"/api/v1/recurring/{rule['id']}", headers=auth, json={"active": False})
    assert (await client.post("/api/v1/recurring/run?today=2026-03-01", headers=auth)).json() == {
        "created": 0
    }
    await client.patch(
        f"/api/v1/recurring/{rule['id']}", headers=auth, json={"active": True, "amount": "900000"}
    )
    res = await client.post("/api/v1/recurring/run?today=2026-01-15", headers=auth)
    assert res.json() == {"created": 1}
    tx = (await client.get("/api/v1/transactions", headers=auth)).json()["items"][0]
    assert tx["amount"] == "900000.00"


async def test_catch_up_is_capped(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    await _mk(client, auth, "recurring", _rule(ids, frequency="weekly", start_date="2000-01-01"))
    first = await client.post("/api/v1/recurring/run?today=2026-01-01", headers=auth)
    assert first.json() == {"created": 120}  # tope por ejecución
    second = await client.post("/api/v1/recurring/run?today=2026-01-01", headers=auth)
    assert second.json()["created"] == 120  # la siguiente ejecución continúa el atraso


async def test_recurring_transfer_and_income(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    other = await _mk(
        client,
        auth,
        "accounts",
        {"name": "Ahorro", "type": "savings", "currency": "COP", "initial_balance": "0"},
    )
    pay = await _mk(client, auth, "categories", {"name": "Sueldo", "kind": "income"})
    await _mk(
        client,
        auth,
        "recurring",
        {
            "type": "income",
            "account_id": ids["account"],
            "category_id": pay["id"],
            "amount": "3000000",
            "frequency": "monthly",
            "start_date": "2026-03-01",
        },
    )
    await _mk(
        client,
        auth,
        "recurring",
        {
            "type": "transfer",
            "account_id": ids["account"],
            "transfer_account_id": other["id"],
            "amount": "500000",
            "frequency": "monthly",
            "start_date": "2026-03-02",
        },
    )
    assert (await client.post("/api/v1/recurring/run?today=2026-03-05", headers=auth)).json() == {
        "created": 2
    }
    accounts = {
        a["name"]: a["balance"] for a in (await client.get("/api/v1/accounts", headers=auth)).json()
    }
    assert accounts == {"Caja": "2500000.00", "Ahorro": "500000.00"}


async def test_validation_rules(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    url = "/api/v1/recurring"
    bad_end = await client.post(url, headers=auth, json=_rule(ids, end_date="2025-01-01"))
    assert bad_end.status_code == 422 and "fecha final" in bad_end.json()["error"]["message"]
    no_target = await client.post(
        url, headers=auth, json=_rule(ids, type="transfer", category_id=None)
    )
    assert no_target.status_code == 422
    wrong_cat = await client.post(url, headers=auth, json=_rule(ids, type="income"))
    assert wrong_cat.status_code == 400  # categoría de gasto en un ingreso
    assert (await client.post(url, headers=auth, json=_rule(ids, amount="0"))).status_code == 422
    assert (
        await client.post(url, headers=auth, json=_rule(ids, frequency="daily"))
    ).status_code == 422


async def test_rules_are_private_and_deletable(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    rule = await _mk(client, auth, "recurring", _rule(ids))
    other = await register_and_login(client, "b@example.com")
    assert (await client.get("/api/v1/recurring", headers=other)).json() == []
    assert (
        await client.patch(f"/api/v1/recurring/{rule['id']}", headers=other, json={"active": False})
    ).status_code == 404
    assert (
        await client.delete(f"/api/v1/recurring/{rule['id']}", headers=other)
    ).status_code == 404
    assert (await client.post("/api/v1/recurring/run?today=2030-01-01", headers=other)).json() == {
        "created": 0
    }
    assert (await client.delete(f"/api/v1/recurring/{rule['id']}", headers=auth)).status_code == 204
    assert (await client.get("/api/v1/recurring", headers=auth)).json() == []


@pytest.mark.parametrize(
    "method,path", [("get", "/api/v1/recurring"), ("post", "/api/v1/recurring/run")]
)
async def test_requires_auth(client: AsyncClient, method: str, path: str) -> None:
    assert (await getattr(client, method)(path)).status_code == 401
