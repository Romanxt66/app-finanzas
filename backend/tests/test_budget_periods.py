from httpx import AsyncClient

H = dict[str, str]
API = "/api/v1"


async def _mk(c: AsyncClient, h: H, path: str, body: dict[str, object]) -> dict[str, object]:
    r = await c.post(f"{API}/{path}", headers=h, json=body)
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
    return {"account": str(acc["id"]), "food": str(food["id"]), "fun": str(fun["id"])}


async def _spend(
    c: AsyncClient, h: H, ids: dict[str, str], cat: str, amount: str, day: str
) -> None:
    await _mk(
        c,
        h,
        "transactions",
        {
            "type": "expense",
            "account_id": ids["account"],
            "category_id": ids[cat],
            "amount": amount,
            "occurred_on": day,
        },
    )


async def _list(c: AsyncClient, h: H, period: str, day: str) -> list[dict[str, object]]:
    r = await c.get(f"{API}/budgets", headers=h, params={"period": period, "date": day})
    assert r.status_code == 200, r.text
    return list(r.json())


async def test_presupuesto_general_del_dia_cuenta_todos_los_gastos(
    client: AsyncClient, auth: H
) -> None:
    ids = await _setup(client, auth)
    await _mk(client, auth, "budgets", {"period": "day", "start": "2026-11-10", "amount": "50000"})
    await _spend(client, auth, ids, "food", "20000", "2026-11-10")
    await _spend(client, auth, ids, "fun", "15000", "2026-11-10")
    await _spend(client, auth, ids, "fun", "99000", "2026-11-09")  # otro día: no cuenta

    [today] = await _list(client, auth, "day", "2026-11-10")
    assert today["category_id"] is None
    assert (today["spent"], today["remaining"]) == ("35000.00", "15000.00")
    assert today["start"] == today["end"] == "2026-11-10"
    assert await _list(client, auth, "day", "2026-11-11") == []


async def test_semana_empieza_el_lunes(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    b = await _mk(
        client,
        auth,
        "budgets",
        {"category_id": ids["food"], "period": "week", "start": "2026-11-12", "amount": "100000"},
    )
    assert (b["start"], b["end"]) == ("2026-11-09", "2026-11-15")
    await _spend(client, auth, ids, "food", "30000", "2026-11-09")
    await _spend(client, auth, ids, "food", "30000", "2026-11-15")
    await _spend(client, auth, ids, "food", "30000", "2026-11-16")  # semana siguiente
    [week] = await _list(client, auth, "week", "2026-11-11")
    assert week["spent"] == "60000.00"


async def test_recurrente_se_repite_y_uno_puntual_lo_sustituye(
    client: AsyncClient, auth: H
) -> None:
    ids = await _setup(client, auth)
    rec = await _mk(
        client,
        auth,
        "budgets",
        {
            "category_id": ids["food"],
            "period": "month",
            "start": "2026-10-05",
            "amount": "400000",
            "recurring": True,
        },
    )
    assert rec["start"] == "2026-10-01" and rec["recurring"] is True
    await _spend(client, auth, ids, "food", "100000", "2027-02-03")

    [feb] = await _list(client, auth, "month", "2027-02-20")
    assert (feb["id"], feb["start"], feb["end"]) == (rec["id"], "2027-02-01", "2027-02-28")
    assert feb["spent"] == "100000.00" and feb["starts_on"] == "2026-10-01"
    assert await _list(client, auth, "month", "2026-09-15") == []  # antes de empezar

    # Diciembre con otro monto solo ese mes
    dec = await _mk(
        client,
        auth,
        "budgets",
        {"category_id": ids["food"], "month": "2026-12-01", "amount": "900000"},
    )
    [in_dec] = await _list(client, auth, "month", "2026-12-24")
    assert in_dec["id"] == dec["id"] and in_dec["amount"] == "900000.00"
    [in_jan] = await _list(client, auth, "month", "2027-01-10")
    assert in_jan["id"] == rec["id"]

    # Compatibilidad: ?month= devuelve lo mismo que period=month
    old = (await client.get(f"{API}/budgets", headers=auth, params={"month": "2027-01-01"})).json()
    assert [b["id"] for b in old] == [rec["id"]]


async def test_no_se_duplican(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    body = {"period": "day", "start": "2026-11-10", "amount": "1000"}
    await _mk(client, auth, "budgets", body)
    again = await client.post(f"{API}/budgets", headers=auth, json=body)
    assert again.status_code == 409  # el general (sin categoría) también se vigila
    rec = {
        "category_id": ids["fun"],
        "period": "week",
        "start": "2026-11-10",
        "amount": "1",
        "recurring": True,
    }
    await _mk(client, auth, "budgets", rec)
    other = await client.post(f"{API}/budgets", headers=auth, json={**rec, "start": "2027-01-01"})
    assert other.status_code == 409


async def test_editar_monto_categoria_y_repeticion(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    b = await _mk(
        client,
        auth,
        "budgets",
        {"category_id": ids["food"], "month": "2026-11-01", "amount": "100"},
    )
    r = await client.patch(
        f"{API}/budgets/{b['id']}",
        headers=auth,
        json={"amount": "250", "category_id": ids["fun"], "recurring": True},
    )
    assert r.status_code == 200, r.text
    out = r.json()
    assert (out["amount"], out["category_id"], out["recurring"]) == ("250.00", ids["fun"], True)
    general = await client.patch(
        f"{API}/budgets/{b['id']}", headers=auth, json={"category_id": None}
    )
    assert general.json()["category_id"] is None


async def test_disponible_hoy_usa_el_mensual_general_si_existe(
    client: AsyncClient, auth: H
) -> None:
    ids = await _setup(client, auth)
    await _mk(
        client,
        auth,
        "budgets",
        {"category_id": ids["food"], "month": "2026-11-01", "amount": "100000"},
    )
    await _mk(
        client,
        auth,
        "budgets",
        {"period": "month", "start": "2026-01-01", "amount": "3000000", "recurring": True},
    )
    r = await client.get(f"{API}/daily-allowance", headers=auth, params={"today": "2026-11-10"})
    assert r.status_code == 200, r.text
    assert r.json()["basis"] == "budget"
    assert r.json()["month_total"] == "3000000.00"


async def test_aviso_de_presupuesto_diario(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    await _mk(client, auth, "budgets", {"period": "day", "start": "2026-11-10", "amount": "10000"})
    await _spend(client, auth, ids, "fun", "12000", "2026-11-10")
    items = (
        await client.get(f"{API}/notifications", headers=auth, params={"today": "2026-11-10"})
    ).json()["items"]
    assert items[0]["title"] == "Te pasaste de tu presupuesto general de hoy"
    assert items[0]["body"] == "Llevas 120 % de lo previsto hoy."


async def test_ajustar_saldo_de_una_cuenta(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    await _spend(client, auth, ids, "food", "30000", "2026-11-10")
    r = await client.patch(
        f"{API}/accounts/{ids['account']}", headers=auth, json={"balance": "500000"}
    )
    assert r.status_code == 200, r.text
    acc = r.json()
    assert acc["balance"] == "500000.00"
    assert acc["initial_balance"] == "530000.00"  # el movimiento sigue ahí
    renamed = await client.patch(
        f"{API}/accounts/{ids['account']}", headers=auth, json={"name": "Nu", "type": "cash"}
    )
    assert (renamed.json()["name"], renamed.json()["type"]) == ("Nu", "cash")


async def test_editar_un_recurrente(client: AsyncClient, auth: H) -> None:
    ids = await _setup(client, auth)
    other = await _mk(
        client,
        auth,
        "accounts",
        {"name": "Banco", "type": "bank", "currency": "COP", "initial_balance": "0"},
    )
    rule = await _mk(
        client,
        auth,
        "recurring",
        {
            "type": "expense",
            "account_id": ids["account"],
            "category_id": ids["food"],
            "amount": "44900",
            "description": "Netflix",
            "frequency": "monthly",
            "start_date": "2026-11-05",
        },
    )
    r = await client.patch(
        f"{API}/recurring/{rule['id']}",
        headers=auth,
        json={
            "amount": "49900",
            "description": "Netflix Premium",
            "account_id": other["id"],
            "category_id": ids["fun"],
            "next_date": "2026-12-20",
        },
    )
    assert r.status_code == 200, r.text
    out = r.json()
    assert (out["amount"], out["description"], out["account_id"]) == (
        "49900.00",
        "Netflix Premium",
        other["id"],
    )
    assert (out["category_id"], out["next_date"]) == (ids["fun"], "2026-12-20")
    bad = await client.patch(
        f"{API}/recurring/{rule['id']}", headers=auth, json={"end_date": "2026-12-01"}
    )
    assert bad.status_code == 400
