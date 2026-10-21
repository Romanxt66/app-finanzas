from httpx import AsyncClient

from tests.conftest import register_and_login

H = dict[str, str]


async def _account(c: AsyncClient, h: H, name: str = "Banco", initial: str = "100.00") -> str:
    r = await c.post(
        "/api/v1/accounts",
        headers=h,
        json={"name": name, "type": "bank", "currency": "usd", "initial_balance": initial},
    )
    assert r.status_code == 201, r.text
    return str(r.json()["id"])


async def _category(c: AsyncClient, h: H, name: str, kind: str) -> str:
    r = await c.post("/api/v1/categories", headers=h, json={"name": name, "kind": kind})
    assert r.status_code == 201, r.text
    return str(r.json()["id"])


async def _tx(c: AsyncClient, h: H, **body: object) -> object:
    return await c.post("/api/v1/transactions", headers=h, json=body)


async def test_balance_follows_transactions(client: AsyncClient, auth: H) -> None:
    a = await _account(client, auth, "A", "100.00")
    b = await _account(client, auth, "B", "0.00")
    salary = await _category(client, auth, "Salario", "income")
    food = await _category(client, auth, "Comida", "expense")
    base = {"account_id": a, "occurred_on": "2026-03-10"}
    await _tx(client, auth, type="income", amount="50.50", category_id=salary, **base)
    await _tx(client, auth, type="expense", amount="20.25", category_id=food, **base)
    await _tx(client, auth, type="transfer", amount="30.00", transfer_account_id=b, **base)

    accounts = {x["name"]: x for x in (await client.get("/api/v1/accounts", headers=auth)).json()}
    assert accounts["A"]["balance"] == "100.25"
    assert accounts["B"]["balance"] == "30.00"
    assert accounts["A"]["currency"] == "USD"


async def test_transaction_validation(client: AsyncClient, auth: H) -> None:
    a = await _account(client, auth)
    food = await _category(client, auth, "Comida", "expense")
    base = {"account_id": a, "occurred_on": "2026-03-10"}
    assert (await _tx(client, auth, type="expense", amount="0", **base)).status_code == 422  # type: ignore[attr-defined]
    assert (await _tx(client, auth, type="transfer", amount="5", **base)).status_code == 422  # type: ignore[attr-defined]
    wrong_kind = await _tx(client, auth, type="income", amount="5", category_id=food, **base)
    assert wrong_kind.status_code == 400  # type: ignore[attr-defined]


async def test_data_is_isolated_between_users(client: AsyncClient, auth: H) -> None:
    a = await _account(client, auth)
    other = await register_and_login(client, "b@example.com")
    assert (await client.get(f"/api/v1/accounts/{a}", headers=other)).status_code == 404
    r = await _tx(client, other, type="income", amount="5", account_id=a, occurred_on="2026-03-10")
    assert r.status_code == 404  # type: ignore[attr-defined]


async def test_transactions_filter_and_pagination(client: AsyncClient, auth: H) -> None:
    a = await _account(client, auth)
    for day, desc in ((1, "café"), (2, "cena"), (3, "café doble")):
        await _tx(
            client,
            auth,
            type="expense",
            amount="3",
            account_id=a,
            occurred_on=f"2026-03-0{day}",
            description=desc,
        )
    page = (await client.get("/api/v1/transactions?search=café&limit=1", headers=auth)).json()
    assert page["total"] == 2 and len(page["items"]) == 1
    assert page["items"][0]["occurred_on"] == "2026-03-03"


async def test_budget_progress_and_summary(client: AsyncClient, auth: H) -> None:
    a = await _account(client, auth)
    food = await _category(client, auth, "Comida", "expense")
    salary = await _category(client, auth, "Salario", "income")
    r = await client.post(
        "/api/v1/budgets",
        headers=auth,
        json={"category_id": food, "month": "2026-03-15", "amount": "200"},
    )
    assert r.status_code == 201 and r.json()["month"] == "2026-03-01"
    await _tx(
        client,
        auth,
        type="expense",
        amount="75",
        account_id=a,
        category_id=food,
        occurred_on="2026-03-20",
    )
    await _tx(
        client,
        auth,
        type="income",
        amount="500",
        account_id=a,
        category_id=salary,
        occurred_on="2026-03-01",
    )
    budget = (await client.get("/api/v1/budgets?month=2026-03-01", headers=auth)).json()[0]
    assert budget["spent"] == "75.00" and budget["remaining"] == "125.00"

    dup = await client.post(
        "/api/v1/budgets",
        headers=auth,
        json={"category_id": food, "month": "2026-03-01", "amount": "10"},
    )
    assert dup.status_code == 409

    s = (await client.get("/api/v1/reports/summary?month=2026-03-01", headers=auth)).json()
    assert (s["income"], s["expense"], s["net"]) == ("500.00", "75.00", "425.00")
    assert len(s["trend"]) == 6 and s["expense_by_category"][0]["category_id"] == food


async def test_cannot_delete_category_in_use(client: AsyncClient, auth: H) -> None:
    a = await _account(client, auth)
    food = await _category(client, auth, "Comida", "expense")
    await _tx(
        client,
        auth,
        type="expense",
        amount="5",
        account_id=a,
        category_id=food,
        occurred_on="2026-03-01",
    )
    assert (await client.delete(f"/api/v1/categories/{food}", headers=auth)).status_code == 409
