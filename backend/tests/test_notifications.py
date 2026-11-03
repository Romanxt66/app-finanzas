import uuid
from datetime import UTC, datetime, timedelta

from httpx import AsyncClient
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from app.models import WaitingItem

H = dict[str, str]
URL = "/api/v1/notifications"


async def _mk(c: AsyncClient, h: H, path: str, body: dict[str, object]) -> dict[str, str]:
    r = await c.post(f"/api/v1/{path}", headers=h, json=body)
    assert r.status_code == 201, r.text
    return dict(r.json())


async def _setup(c: AsyncClient, h: H) -> dict[str, str]:
    acc = await _mk(
        c,
        h,
        "accounts",
        {"name": "Nequi", "type": "bank", "currency": "COP", "initial_balance": "0"},
    )
    food = await _mk(c, h, "categories", {"name": "Comida", "kind": "expense"})
    fun = await _mk(c, h, "categories", {"name": "Ocio", "kind": "expense"})
    return {"account": acc["id"], "food": food["id"], "fun": fun["id"]}


async def _expense(c: AsyncClient, h: H, ids: dict[str, str], cat: str, amount: str) -> None:
    await _mk(
        c,
        h,
        "transactions",
        {
            "type": "expense",
            "account_id": ids["account"],
            "category_id": ids[cat],
            "amount": amount,
            "occurred_on": "2099-01-10",
        },
    )


async def test_empty_when_nothing_pending(client: AsyncClient, auth: H) -> None:
    r = await client.get(URL, headers=auth)
    assert r.status_code == 200 and r.json() == {"items": []}


async def test_budgets_recurring_and_order(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    for cat in ("food", "fun"):
        await _mk(
            client,
            auth,
            "budgets",
            {"category_id": ids[cat], "month": "2099-01-01", "amount": "100000"},
        )
    await _expense(client, auth, ids, "food", "85000")  # 85 %: aviso
    await _expense(client, auth, ids, "fun", "120000")  # 120 %: superado
    await _mk(
        client,
        auth,
        "recurring",
        {
            "type": "expense",
            "account_id": ids["account"],
            "amount": "44900",
            "description": "Netflix",
            "frequency": "monthly",
            "start_date": "2099-01-16",
        },
    )
    await _mk(
        client,
        auth,
        "recurring",
        {
            "type": "expense",
            "account_id": ids["account"],
            "amount": "10",
            "description": "Lejano",
            "frequency": "monthly",
            "start_date": "2099-01-28",
        },
    )

    items = (await client.get(URL, headers=auth, params={"today": "2099-01-15"})).json()["items"]
    assert [i["kind"] for i in items] == ["budget_exceeded", "budget_warning", "recurring_due"]
    assert items[0]["title"] == "Te pasaste del presupuesto de Ocio"
    assert items[0]["id"].endswith(":over")
    assert items[1]["title"] == "Vas al 85 % del presupuesto de Comida"
    assert items[2]["title"] == "Netflix se cobra mañana"
    assert items[2]["body"] == "Ten listos 44.900 COP en la cuenta."
    assert (items[2]["severity"], items[2]["link"]) == ("warning", "/recurring")

    later = (
        await client.get(URL, headers=auth, params={"today": "2099-01-15", "days": 14})
    ).json()["items"]
    assert [i["title"] for i in later if i["kind"] == "recurring_due"] == [
        "Netflix se cobra mañana",
        "Lejano se cobra en 13 días",
    ]


async def test_waiting_item_ready(client: AsyncClient, auth: H, engine: AsyncEngine) -> None:
    created = await _mk(
        client, auth, "waiting-room", {"name": "Audífonos", "amount": "250000", "currency": "COP"}
    )
    assert (await client.get(URL, headers=auth)).json()["items"] == []
    async with async_sessionmaker(engine)() as session:
        await session.execute(
            update(WaitingItem)
            .where(WaitingItem.id == uuid.UUID(created["id"]))
            .values(ready_at=datetime.now(UTC) - timedelta(hours=1))
        )
        await session.commit()
    items = (await client.get(URL, headers=auth)).json()["items"]
    assert [(i["kind"], i["title"], i["link"]) for i in items] == [
        ("waiting_ready", "Ya puedes decidir: Audífonos", "/waiting")
    ]


async def test_other_users_data_is_not_visible(client: AsyncClient, auth: H) -> None:
    from tests.conftest import register_and_login

    ids = await _setup(client, auth)
    await _mk(
        client,
        auth,
        "budgets",
        {"category_id": ids["food"], "month": "2099-01-01", "amount": "100"},
    )
    await _expense(client, auth, ids, "food", "500")
    other = await register_and_login(client, "b@example.com")
    r = await client.get(URL, headers=other, params={"today": "2099-01-15"})
    assert r.json() == {"items": []}
