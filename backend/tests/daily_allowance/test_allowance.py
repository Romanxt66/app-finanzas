from datetime import date, timedelta
from decimal import Decimal

from httpx import AsyncClient

from app.schemas.daily_allowance import Basis, DailyAllowance, Status
from app.services.daily_allowance import compute, weekday_weights

D = Decimal
NEUTRAL = {weekday: D(1) for weekday in range(7)}
WEDNESDAY = date(2026, 10, 21)  # quedan 11 días del mes contando hoy


def run(**over: object) -> DailyAllowance:
    params: dict[str, object] = dict(
        today=WEDNESDAY,
        currency="EUR",
        basis=Basis.budget,
        month_total=D(1000),
        spent_before_today=D(200),
        spent_today=D(20),
        pending_committed=D(100),
        weights=NEUTRAL,
        pattern_used=False,
    )
    params.update(over)
    return compute(**params)  # type: ignore[arg-type]


def test_splits_the_remainder_evenly_without_pattern() -> None:
    result = run()
    assert result.days_remaining == 11
    assert result.allowance_today == D("63.64")  # 700 / 11
    assert result.left_today == D("43.64")
    assert result.status == Status.ok


def test_tight_when_today_already_exceeds_share() -> None:
    result = run(spent_today=D(100))
    assert result.left_today == D("-36.36")
    assert result.status == Status.tight


def test_over_when_nothing_is_left_for_the_month() -> None:
    result = run(spent_before_today=D(950))
    assert result.allowance_today == D(0)
    assert result.status == Status.over


def test_no_data_without_budget_or_income() -> None:
    assert run(month_total=D(0)).status == Status.no_data


def test_heavier_days_get_a_bigger_share() -> None:
    weights = {**NEUTRAL, WEDNESDAY.weekday(): D(2)}
    result = run(weights=weights, pattern_used=True)
    # Quedan dos miércoles (21 y 28) de peso 2 y nueve días de peso 1: 2*2 + 9 = 13
    assert result.allowance_today == D("107.69")  # 700 * 2 / 13


def test_weekday_weights_need_enough_history() -> None:
    today = WEDNESDAY
    weights, used = weekday_weights([(date(2026, 10, 15), D(50))], today)
    assert not used
    assert weights == NEUTRAL


def test_weekday_weights_need_several_days_with_spending() -> None:
    few = [(date(2026, 10, 3), D(100)), (date(2026, 10, 10), D(100))]
    assert weekday_weights(few, WEDNESDAY) == (NEUTRAL, False)


def test_weekday_weights_follow_spending_pattern() -> None:
    expenses: list[tuple[date, D]] = []
    for week in range(7):
        saturday = date(2026, 10, 17) - timedelta(days=7 * week)
        expenses.append((saturday, D(100)))
        expenses.append((saturday + timedelta(days=2), D(1)))  # un gasto pequeño cada lunes
        expenses.append((saturday - timedelta(days=3), D(1)))  # y cada miércoles
    weights, used = weekday_weights(expenses, WEDNESDAY)
    assert used
    assert weights[5] == D(3)  # sábado: tope
    assert weights[4] == D("0.3")  # viernes sin gasto: piso


async def _setup(client: AsyncClient, h: dict[str, str], currency: str = "EUR") -> str:
    r = await client.post(
        "/api/v1/accounts",
        headers=h,
        json={"name": "Banco", "type": "bank", "currency": currency, "initial_balance": "0"},
    )
    return str(r.json()["id"])


async def test_endpoint_uses_budget_and_recurring_rules(
    client: AsyncClient, auth: dict[str, str]
) -> None:
    account = await _setup(client, auth)
    category = (
        await client.post(
            "/api/v1/categories", headers=auth, json={"name": "Vida", "kind": "expense"}
        )
    ).json()["id"]
    await client.post(
        "/api/v1/budgets",
        headers=auth,
        json={"category_id": category, "month": "2026-10-01", "amount": "1000.00"},
    )
    await client.post(
        "/api/v1/transactions",
        headers=auth,
        json={
            "type": "expense",
            "account_id": account,
            "category_id": category,
            "amount": "200.00",
            "occurred_on": "2026-10-05",
        },
    )
    await client.post(
        "/api/v1/recurring",
        headers=auth,
        json={
            "type": "expense",
            "account_id": account,
            "amount": "100.00",
            "description": "Alquiler trastero",
            "frequency": "monthly",
            "start_date": "2026-10-28",
        },
    )
    r = await client.get("/api/v1/daily-allowance", headers=auth, params={"today": "2026-10-21"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["basis"] == "budget"
    assert body["currency"] == "EUR"
    assert body["spent_before_today"] == "200.00"
    assert body["pending_committed"] == "100.00"
    assert body["allowance_today"] == "63.64"
    assert body["status"] == "ok"


async def test_endpoint_falls_back_to_income_and_needs_an_account(
    client: AsyncClient, auth: dict[str, str]
) -> None:
    missing = await client.get("/api/v1/daily-allowance", headers=auth)
    assert missing.status_code == 404
    account = await _setup(client, auth)
    category = (
        await client.post(
            "/api/v1/categories", headers=auth, json={"name": "Nómina", "kind": "income"}
        )
    ).json()["id"]
    await client.post(
        "/api/v1/transactions",
        headers=auth,
        json={
            "type": "income",
            "account_id": account,
            "category_id": category,
            "amount": "1100.00",
            "occurred_on": "2026-10-01",
        },
    )
    body = (
        await client.get("/api/v1/daily-allowance", headers=auth, params={"today": "2026-10-21"})
    ).json()
    assert body["basis"] == "income"
    assert body["allowance_today"] == "100.00"  # 1100 / 11


async def test_other_currency_accounts_are_not_mixed(
    client: AsyncClient, auth: dict[str, str]
) -> None:
    eur = await _setup(client, auth, "EUR")
    usd = await _setup(client, auth, "USD")
    for account, amount in ((eur, "500.00"), (usd, "999.00")):
        await client.post(
            "/api/v1/transactions",
            headers=auth,
            json={
                "type": "income",
                "account_id": account,
                "amount": amount,
                "occurred_on": "2026-10-01",
            },
        )
    r = await client.get(
        "/api/v1/daily-allowance", headers=auth, params={"today": "2026-10-21", "currency": "usd"}
    )
    assert r.json()["currency"] == "USD"
    assert r.json()["month_total"] == "999.00"
