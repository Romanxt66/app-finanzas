from datetime import date
from decimal import Decimal

from httpx import AsyncClient

from app.models import SpendingMood
from app.schemas.insights import Comparison
from app.services.insights import Expense, inflation, moods
from tests.conftest import register_and_login

H = dict[str, str]
TODAY = date(2026, 10, 27)


def exp(
    desc: str,
    amount: str,
    day: str,
    category: str | None = "Comida",
    currency: str = "EUR",
    mood: SpendingMood | None = None,
) -> Expense:
    return Expense(desc, Decimal(amount), date.fromisoformat(day), currency, category, mood)


def test_weighted_index_against_last_year() -> None:
    data = [
        # Hace un año
        exp("Supermercado Día", "50", "2025-09-10"),
        exp("Café Luna", "2.00", "2025-10-01"),
        # Ahora: el súper sube un 10 % y el café un 50 %
        exp("Supermercado Día", "55", "2026-09-10"),
        exp("SUPERMERCADO DIA 4411", "55", "2026-10-10"),
        exp("Café Luna", "3.00", "2026-10-20", category="Ocio"),
    ]
    report = inflation(data, TODAY)
    assert report.comparison == Comparison.year
    assert report.matched == 2
    assert report.currency == "EUR"
    # (1,10 · 110 + 1,50 · 3) / 113 − 1
    assert report.index_pct == Decimal("11.1")
    assert report.coverage_pct == Decimal("100.0")
    top = report.items[0]
    assert top.merchant == "SUPERMERCADO DIA 4411"
    assert (top.base_price, top.current_price, top.change_pct) == (
        Decimal("50.00"),
        Decimal("55.00"),
        Decimal("10.0"),
    )
    assert [c.category for c in report.categories] == ["Ocio", "Comida"]


def test_falls_back_to_six_months_and_ignores_other_currencies() -> None:
    data = [
        exp("Gasolina", "60", "2026-04-20"),
        exp("Panadería", "3", "2026-04-21"),
        exp("Gasolina", "54", "2026-10-01"),
        exp("Panadería", "3", "2026-10-02"),
        exp("Gasolina", "20", "2026-10-03", currency="USD"),
    ]
    report = inflation(data, TODAY)
    assert report.comparison == Comparison.half_year
    assert report.currency == "EUR"
    assert report.index_pct == Decimal("-9.5")


def test_not_enough_history() -> None:
    report = inflation([exp("Café", "2", "2026-10-01")], TODAY)
    assert report.index_pct is None
    assert report.items == []
    assert inflation([], TODAY).currency is None


def test_mood_highlight_finds_costliest_mood() -> None:
    stressed = SpendingMood.stressed
    data = [
        exp("Pedido", "30", "2026-10-02", mood=stressed),  # viernes
        exp("Pedido", "36", "2026-10-09", mood=stressed),  # viernes
        exp("Ropa", "24", "2026-10-15", mood=stressed),  # jueves
        exp("Café", "3", "2026-10-03", mood=SpendingMood.happy),
        exp("Súper", "20", "2026-10-04"),
        exp("Súper", "27", "2026-10-05"),
    ]
    report = moods(data, TODAY)
    assert (report.expenses, report.tagged) == (6, 4)
    assert report.by_mood[0].mood == stressed
    assert report.by_mood[0].average == Decimal("30.00")
    assert report.highlight is not None
    assert report.highlight.mood == stressed
    assert report.highlight.baseline == Decimal("23.33")
    assert report.highlight.change_pct == Decimal("28.6")
    assert report.highlight.top_weekday == 5


def test_mood_without_tags() -> None:
    report = moods([exp("Súper", "20", "2026-10-04")], TODAY)
    assert report.tagged == 0
    assert report.highlight is None


async def _setup(client: AsyncClient, auth: H) -> tuple[str, str]:
    acc = (
        await client.post(
            "/api/v1/accounts",
            headers=auth,
            json={"name": "Banco", "type": "bank", "currency": "EUR", "initial_balance": "0"},
        )
    ).json()["id"]
    cat = (
        await client.post(
            "/api/v1/categories", headers=auth, json={"name": "Comida", "kind": "expense"}
        )
    ).json()["id"]
    return acc, cat


async def test_mood_is_stored_and_kept_on_edit(client: AsyncClient, auth: H) -> None:
    acc, cat = await _setup(client, auth)
    body = {
        "account_id": acc,
        "category_id": cat,
        "type": "expense",
        "amount": "12.00",
        "description": "Pizza",
        "occurred_on": "2026-10-20",
    }
    r = await client.post("/api/v1/transactions", headers=auth, json=body | {"mood": "stressed"})
    assert r.status_code == 201, r.text
    tx = r.json()
    assert tx["mood"] == "stressed"

    # Un cliente que no conoce el ánimo lo conserva al editar
    r = await client.put(
        f"/api/v1/transactions/{tx['id']}", headers=auth, json=body | {"amount": "13.00"}
    )
    assert r.json()["mood"] == "stressed"
    r = await client.put(
        f"/api/v1/transactions/{tx['id']}", headers=auth, json=body | {"mood": None}
    )
    assert r.json()["mood"] is None

    bad = body | {"type": "income", "category_id": None, "mood": "happy"}
    assert (await client.post("/api/v1/transactions", headers=auth, json=bad)).status_code == 422
    bad = body | {"mood": "furioso"}
    assert (await client.post("/api/v1/transactions", headers=auth, json=bad)).status_code == 422


async def test_insight_endpoints(client: AsyncClient, auth: H) -> None:
    acc, cat = await _setup(client, auth)
    for desc, amount, day, mood in (
        ("Súper", "40", "2025-10-01", None),
        ("Café", "2", "2025-10-02", None),
        ("Súper", "44", "2026-10-01", "calm"),
        ("Café", "2.5", "2026-10-02", "happy"),
    ):
        await client.post(
            "/api/v1/transactions",
            headers=auth,
            json={
                "account_id": acc,
                "category_id": cat,
                "type": "expense",
                "amount": amount,
                "description": desc,
                "occurred_on": day,
                "mood": mood,
            },
        )
    r = await client.get("/api/v1/personal-inflation", headers=auth, params={"today": "2026-10-27"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["comparison"] == "year"
    assert body["matched"] == 2
    assert body["items"][0]["category"] == "Comida"

    r = await client.get("/api/v1/spending-mood", headers=auth, params={"today": "2026-10-27"})
    assert r.json()["tagged"] == 2

    other = await register_and_login(client, "b@example.com")
    r = await client.get("/api/v1/personal-inflation", headers=other)
    assert r.json()["matched"] == 0
