from httpx import AsyncClient

from tests.conftest import register_and_login

H = dict[str, str]


async def _mk(c: AsyncClient, h: H, path: str, body: dict[str, object]) -> dict[str, str]:
    r = await c.post(f"/api/v1/{path}", headers=h, json=body)
    assert r.status_code == 201, r.text
    return dict(r.json())


async def _fill(c: AsyncClient, h: H) -> None:
    """Un poco de todo: cuenta, categoría, movimiento, presupuesto, meta con aporte y recurrente."""
    acc = await _mk(
        c,
        h,
        "accounts",
        {"name": "Caja", "type": "bank", "currency": "COP", "initial_balance": "0"},
    )
    cat = await _mk(c, h, "categories", {"name": "Comida", "kind": "expense"})
    await _mk(
        c,
        h,
        "transactions",
        {
            "type": "expense",
            "account_id": acc["id"],
            "category_id": cat["id"],
            "amount": "12000",
            "occurred_on": "2026-03-02",
        },
    )
    await _mk(c, h, "budgets", {"category_id": cat["id"], "month": "2026-03-01", "amount": "200"})
    goal = await _mk(c, h, "goals", {"name": "Viaje", "target_amount": "100", "currency": "COP"})
    await _mk(
        c, h, f"goals/{goal['id']}/contributions", {"amount": "5", "occurred_on": "2026-03-02"}
    )
    await _mk(
        c,
        h,
        "recurring",
        {
            "type": "expense",
            "account_id": acc["id"],
            "category_id": cat["id"],
            "amount": "800000",
            "description": "Arriendo",
            "frequency": "monthly",
            "start_date": "2026-01-31",
        },
    )


async def test_delete_account_removes_everything_and_only_mine(client: AsyncClient) -> None:
    me = await register_and_login(client, "yo@example.com")
    other = await register_and_login(client, "otra@example.com")
    await _fill(client, me)
    await _fill(client, other)

    r = await client.request(
        "DELETE", "/api/v1/auth/me", headers=me, json={"password": "password-123"}
    )
    assert r.status_code == 204, r.text

    # El token ya no sirve y no se puede entrar con esa cuenta
    assert (await client.get("/api/v1/auth/me", headers=me)).status_code == 401
    login = await client.post(
        "/api/v1/auth/login", json={"email": "yo@example.com", "password": "password-123"}
    )
    assert login.status_code == 401
    # El correo queda libre para registrarse de nuevo, y la cuenta nueva empieza vacía
    again = await register_and_login(client, "yo@example.com")
    assert (await client.get("/api/v1/accounts", headers=again)).json() == []

    # Los datos de la otra persona siguen intactos
    assert len((await client.get("/api/v1/accounts", headers=other)).json()) == 1
    assert len((await client.get("/api/v1/goals", headers=other)).json()) == 1
    assert len((await client.get("/api/v1/recurring", headers=other)).json()) == 1


async def test_delete_account_requires_the_password(client: AsyncClient, auth: H) -> None:
    r = await client.request("DELETE", "/api/v1/auth/me", headers=auth, json={"password": "mala"})
    assert r.status_code == 400
    assert (await client.get("/api/v1/auth/me", headers=auth)).status_code == 200
    unauthenticated = await client.request(
        "DELETE", "/api/v1/auth/me", json={"password": "password-123"}
    )
    assert unauthenticated.status_code == 401
