from decimal import Decimal

from httpx import AsyncClient

from tests.conftest import register_and_login

H = dict[str, str]


async def _mk(c: AsyncClient, h: H, path: str, body: dict[str, object]) -> dict[str, str]:
    r = await c.post(f"/api/v1/{path}", headers=h, json=body)
    assert r.status_code == 201, r.text
    return dict(r.json())


def _acc(name: str = "Caja", currency: str = "USD", initial: str = "0") -> dict[str, object]:
    return {"name": name, "type": "cash", "currency": currency, "initial_balance": initial}


# ---- cuentas ----------------------------------------------------------------
async def test_archive_hides_account_by_default(client: AsyncClient, auth: H) -> None:
    acc = await _mk(client, auth, "accounts", _acc())
    r = await client.patch(f"/api/v1/accounts/{acc['id']}", headers=auth, json={"archived": True})
    assert r.json()["archived"] is True
    assert (await client.get("/api/v1/accounts", headers=auth)).json() == []
    listed = await client.get("/api/v1/accounts?include_archived=true", headers=auth)
    assert len(listed.json()) == 1


async def test_account_rename_and_validation(client: AsyncClient, auth: H) -> None:
    acc = await _mk(client, auth, "accounts", _acc())
    r = await client.patch(f"/api/v1/accounts/{acc['id']}", headers=auth, json={"name": "Nueva"})
    assert r.json()["name"] == "Nueva"
    bad = {**_acc(), "currency": "USDD"}
    assert (await client.post("/api/v1/accounts", headers=auth, json=bad)).status_code == 422
    bad = {**_acc(), "type": "crypto"}
    assert (await client.post("/api/v1/accounts", headers=auth, json=bad)).status_code == 422
    bad = {**_acc(), "initial_balance": "1.234"}
    assert (await client.post("/api/v1/accounts", headers=auth, json=bad)).status_code == 422


async def test_negative_initial_balance_allowed(client: AsyncClient, auth: H) -> None:
    acc = await _mk(client, auth, "accounts", _acc("Tarjeta", initial="-50.00"))
    assert acc["balance"] == "-50.00"


# ---- categorías -------------------------------------------------------------
async def test_category_crud_and_duplicates(client: AsyncClient, auth: H) -> None:
    cat = await _mk(client, auth, "categories", {"name": "Comida", "kind": "expense"})
    dup = await client.post(
        "/api/v1/categories", headers=auth, json={"name": "Comida", "kind": "expense"}
    )
    assert dup.status_code == 409
    same_name_other_kind = await client.post(
        "/api/v1/categories", headers=auth, json={"name": "Comida", "kind": "income"}
    )
    assert same_name_other_kind.status_code == 201
    renamed = await client.patch(
        f"/api/v1/categories/{cat['id']}", headers=auth, json={"name": "Alimentos"}
    )
    assert renamed.json()["name"] == "Alimentos"
    assert (await client.delete(f"/api/v1/categories/{cat['id']}", headers=auth)).status_code == 204
    assert len((await client.get("/api/v1/categories", headers=auth)).json()) == 1


async def test_rename_to_existing_name_conflicts(client: AsyncClient, auth: H) -> None:
    await _mk(client, auth, "categories", {"name": "A", "kind": "expense"})
    b = await _mk(client, auth, "categories", {"name": "B", "kind": "expense"})
    r = await client.patch(f"/api/v1/categories/{b['id']}", headers=auth, json={"name": "A"})
    assert r.status_code == 409


async def test_categories_are_per_user(client: AsyncClient, auth: H) -> None:
    cat = await _mk(client, auth, "categories", {"name": "Privada", "kind": "expense"})
    other = await register_and_login(client, "b@example.com")
    assert (await client.get("/api/v1/categories", headers=other)).json() == []
    r = await client.delete(f"/api/v1/categories/{cat['id']}", headers=other)
    assert r.status_code == 404
    same = await client.post(
        "/api/v1/categories", headers=other, json={"name": "Privada", "kind": "expense"}
    )
    assert same.status_code == 201


# ---- transacciones ----------------------------------------------------------
def _tx(account: str, **over: object) -> dict[str, object]:
    return {
        "type": "expense",
        "account_id": account,
        "amount": "10.00",
        "occurred_on": "2026-03-10",
        "description": "",
        **over,
    }


async def test_transaction_update_and_delete_changes_balance(client: AsyncClient, auth: H) -> None:
    acc = await _mk(client, auth, "accounts", _acc(initial="100"))
    tx = await _mk(client, auth, "transactions", _tx(acc["id"]))
    bal = lambda: client.get(f"/api/v1/accounts/{acc['id']}", headers=auth)  # noqa: E731
    assert (await bal()).json()["balance"] == "90.00"
    r = await client.put(
        f"/api/v1/transactions/{tx['id']}", headers=auth, json=_tx(acc["id"], amount="40")
    )
    assert r.status_code == 200 and (await bal()).json()["balance"] == "60.00"
    assert (
        await client.delete(f"/api/v1/transactions/{tx['id']}", headers=auth)
    ).status_code == 204
    assert (await bal()).json()["balance"] == "100.00"


async def test_transfer_rules(client: AsyncClient, auth: H) -> None:
    usd = await _mk(client, auth, "accounts", _acc("USD", "USD"))
    eur = await _mk(client, auth, "accounts", _acc("EUR", "EUR"))
    cross = _tx(usd["id"], type="transfer", transfer_account_id=eur["id"])
    assert (await client.post("/api/v1/transactions", headers=auth, json=cross)).status_code == 400
    same = _tx(usd["id"], type="transfer", transfer_account_id=usd["id"])
    assert (await client.post("/api/v1/transactions", headers=auth, json=same)).status_code == 422
    stray = _tx(usd["id"], transfer_account_id=eur["id"])
    assert (await client.post("/api/v1/transactions", headers=auth, json=stray)).status_code == 422


async def test_cannot_use_other_users_category_or_account(client: AsyncClient, auth: H) -> None:
    other = await register_and_login(client, "b@example.com")
    foreign_cat = await _mk(client, other, "categories", {"name": "X", "kind": "expense"})
    mine = await _mk(client, auth, "accounts", _acc())
    r = await client.post(
        "/api/v1/transactions", headers=auth, json=_tx(mine["id"], category_id=foreign_cat["id"])
    )
    assert r.status_code == 404


async def test_filters_combine(client: AsyncClient, auth: H) -> None:
    a1 = await _mk(client, auth, "accounts", _acc("A1"))
    a2 = await _mk(client, auth, "accounts", _acc("A2"))
    cat = await _mk(client, auth, "categories", {"name": "C", "kind": "income"})
    await _mk(client, auth, "transactions", _tx(a1["id"], occurred_on="2026-01-05"))
    await _mk(
        client,
        auth,
        "transactions",
        _tx(a2["id"], type="income", category_id=cat["id"], occurred_on="2026-02-05"),
    )
    await _mk(
        client,
        auth,
        "transactions",
        _tx(a1["id"], type="transfer", transfer_account_id=a2["id"], occurred_on="2026-03-05"),
    )

    async def total(query: str) -> int:
        return int(
            (await client.get(f"/api/v1/transactions?{query}", headers=auth)).json()["total"]
        )

    assert await total("") == 3
    assert await total("type=income") == 1
    assert await total(f"category_id={cat['id']}") == 1
    assert await total(f"account_id={a2['id']}") == 2  # incluye la transferencia entrante
    assert await total("date_from=2026-02-01&date_to=2026-02-28") == 1
    assert await total("type=expense&date_from=2026-02-01") == 0


async def test_listing_is_newest_first(client: AsyncClient, auth: H) -> None:
    acc = await _mk(client, auth, "accounts", _acc())
    for day in ("2026-03-01", "2026-03-09", "2026-03-05"):
        await _mk(client, auth, "transactions", _tx(acc["id"], occurred_on=day))
    items = (await client.get("/api/v1/transactions", headers=auth)).json()["items"]
    assert [i["occurred_on"] for i in items] == ["2026-03-09", "2026-03-05", "2026-03-01"]


# ---- presupuestos -----------------------------------------------------------
async def test_budget_only_for_expense_categories(client: AsyncClient, auth: H) -> None:
    inc = await _mk(client, auth, "categories", {"name": "Sueldo", "kind": "income"})
    r = await client.post(
        "/api/v1/budgets",
        headers=auth,
        json={"category_id": inc["id"], "month": "2026-03-01", "amount": "10"},
    )
    assert r.status_code == 400


async def test_budget_update_delete_and_overspend(client: AsyncClient, auth: H) -> None:
    acc = await _mk(client, auth, "accounts", _acc())
    cat = await _mk(client, auth, "categories", {"name": "Ocio", "kind": "expense"})
    b = await _mk(
        client, auth, "budgets", {"category_id": cat["id"], "month": "2026-12-20", "amount": "50"}
    )
    await _mk(
        client,
        auth,
        "transactions",
        _tx(acc["id"], amount="80", category_id=cat["id"], occurred_on="2026-12-31"),
    )
    await _mk(
        client,
        auth,
        "transactions",
        _tx(acc["id"], amount="999", category_id=cat["id"], occurred_on="2027-01-01"),
    )
    upd = await client.patch(f"/api/v1/budgets/{b['id']}", headers=auth, json={"amount": "100"})
    body = upd.json()
    assert (body["spent"], body["remaining"]) == ("80.00", "20.00")  # 1 de enero no cuenta
    assert (await client.delete(f"/api/v1/budgets/{b['id']}", headers=auth)).status_code == 204
    assert (await client.get("/api/v1/budgets", headers=auth)).json() == []


async def test_budget_amount_must_be_positive(client: AsyncClient, auth: H) -> None:
    cat = await _mk(client, auth, "categories", {"name": "Ocio", "kind": "expense"})
    r = await client.post(
        "/api/v1/budgets",
        headers=auth,
        json={"category_id": cat["id"], "month": "2026-03-01", "amount": "0"},
    )
    assert r.status_code == 422


# ---- reportes ---------------------------------------------------------------
async def test_summary_empty(client: AsyncClient, auth: H) -> None:
    s = (await client.get("/api/v1/reports/summary?month=2026-03-01", headers=auth)).json()
    assert [Decimal(s[k]) for k in ("income", "expense", "net")] == [Decimal(0)] * 3
    assert len(s["trend"]) == 6 and s["expense_by_category"] == []


async def test_summary_excludes_transfers_and_handles_year_boundary(
    client: AsyncClient, auth: H
) -> None:
    a = await _mk(client, auth, "accounts", _acc("A"))
    b = await _mk(client, auth, "accounts", _acc("B"))
    await _mk(
        client,
        auth,
        "transactions",
        _tx(a["id"], type="transfer", transfer_account_id=b["id"], occurred_on="2026-01-10"),
    )
    await _mk(client, auth, "transactions", _tx(a["id"], amount="25", occurred_on="2025-12-15"))
    s = (await client.get("/api/v1/reports/summary?month=2026-01-01", headers=auth)).json()
    assert Decimal(s["expense"]) == 0
    assert [m["month"] for m in s["trend"]][0] == "2025-08-01"
    dec = next(m for m in s["trend"] if m["month"] == "2025-12-01")
    assert dec["expense"] == "25.00"


async def test_summary_requires_month(client: AsyncClient, auth: H) -> None:
    assert (await client.get("/api/v1/reports/summary", headers=auth)).status_code == 422


# ---- reportes por moneda ----------------------------------------------------
async def test_summary_separates_currencies(client: AsyncClient, auth: H) -> None:
    cop = await _mk(client, auth, "accounts", _acc("Pesos", "COP"))
    usd = await _mk(client, auth, "accounts", _acc("Dólares", "USD"))
    cat = await _mk(client, auth, "categories", {"name": "Viajes", "kind": "expense"})
    await _mk(
        client,
        auth,
        "transactions",
        _tx(cop["id"], amount="1000", category_id=cat["id"], occurred_on="2026-03-02"),
    )
    await _mk(
        client,
        auth,
        "transactions",
        _tx(usd["id"], amount="25", category_id=cat["id"], occurred_on="2026-03-03"),
    )
    await _mk(
        client,
        auth,
        "transactions",
        _tx(usd["id"], type="income", amount="300", occurred_on="2026-03-04"),
    )
    await _mk(client, auth, "transactions", _tx(usd["id"], amount="10", occurred_on="2026-03-05"))

    def summary(query: str = "") -> object:
        return client.get(f"/api/v1/reports/summary?month=2026-03-01{query}", headers=auth)

    default = (await summary()).json()
    assert (default["currency"], default["currencies"]) == ("COP", ["COP", "USD"])
    assert (default["income"], default["expense"]) == ("0.00", "1000.00")
    usd_sum = (await summary("&currency=usd")).json()
    assert usd_sum["currency"] == "USD"
    assert (usd_sum["income"], usd_sum["expense"], usd_sum["net"]) == ("300.00", "35.00", "265.00")
    assert [(c["category_id"], c["total"]) for c in usd_sum["expense_by_category"]] == [
        (cat["id"], "25.00"),
        (None, "10.00"),
    ]
    assert sum(Decimal(m["expense"]) for m in usd_sum["trend"]) == Decimal("35.00")
    bad = await summary("&currency=EUR")
    assert bad.status_code == 400 and "esa moneda" in bad.json()["error"]["message"]


async def test_summary_without_accounts_has_no_currency(client: AsyncClient, auth: H) -> None:
    s = (await client.get("/api/v1/reports/summary?month=2026-03-01", headers=auth)).json()
    assert s["currency"] is None and s["currencies"] == [] and Decimal(s["net"]) == 0
