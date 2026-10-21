from datetime import date, timedelta
from decimal import Decimal

import pytest
from httpx import ASGITransport, AsyncClient
from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

from app.db.session import get_session
from app.main import create_app
from tests.conftest import QueryCounter, register_and_login

H = dict[str, str]


async def _mk(c: AsyncClient, h: H, path: str, body: dict[str, object]) -> dict[str, str]:
    r = await c.post(f"/api/v1/{path}", headers=h, json=body)
    assert r.status_code == 201, r.text
    return dict(r.json())


# ---- invalidación de sesiones -----------------------------------------------
async def test_password_change_invalidates_other_sessions(client: AsyncClient) -> None:
    other_device = await register_and_login(client)
    tokens = (
        await client.post(
            "/api/v1/auth/login", json={"email": "a@example.com", "password": "password-123"}
        )
    ).json()
    assert (await client.get("/api/v1/auth/me", headers=other_device)).status_code == 200

    changed = await client.post(
        "/api/v1/auth/change-password",
        headers=other_device,
        json={"current_password": "password-123", "new_password": "NuevaClave-99"},
    )
    new_tokens = changed.json()
    # las sesiones anteriores (access y refresh) ya no valen…
    assert (await client.get("/api/v1/auth/me", headers=other_device)).status_code == 401
    refresh = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert refresh.status_code == 401
    # …pero los tokens devueltos mantienen la sesión actual
    fresh = {"Authorization": f"Bearer {new_tokens['access_token']}"}
    assert (await client.get("/api/v1/auth/me", headers=fresh)).status_code == 200
    renewed = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": new_tokens["refresh_token"]}
    )
    assert renewed.status_code == 200


async def test_logout_all_invalidates_everything(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    tokens = (
        await client.post(
            "/api/v1/auth/login", json={"email": "a@example.com", "password": "password-123"}
        )
    ).json()
    assert (await client.post("/api/v1/auth/logout-all", headers=headers)).status_code == 204
    assert (await client.get("/api/v1/auth/me", headers=headers)).status_code == 401
    assert (
        await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    ).status_code == 401
    again = await client.post(
        "/api/v1/auth/login", json={"email": "a@example.com", "password": "password-123"}
    )
    assert again.status_code == 200  # volver a entrar sí funciona


# ---- health -----------------------------------------------------------------
async def test_readiness_checks_database(client: AsyncClient) -> None:
    assert (await client.get("/health/ready")).json() == {"status": "ok", "database": "ok"}


async def test_readiness_reports_503_when_database_is_down() -> None:
    app = create_app()

    class Broken:
        async def execute(self, *_: object) -> None:
            raise RuntimeError("sin conexión")

    async def broken_session():  # type: ignore[no-untyped-def]
        yield Broken()

    app.dependency_overrides[get_session] = broken_session
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as c:
        assert (await c.get("/health/ready")).status_code == 503
        assert (await c.get("/health")).status_code == 200  # liveness no depende de la BD


# ---- sin consultas N+1 ------------------------------------------------------
async def test_goals_and_budgets_lists_do_not_scale_queries(
    client: AsyncClient, auth: H, queries: QueryCounter
) -> None:
    acc = await _mk(
        client,
        auth,
        "accounts",
        {"name": "A", "type": "bank", "currency": "COP", "initial_balance": "0"},
    )
    today = date.today().isoformat()

    async def count(path: str) -> int:
        queries.reset()
        assert (await client.get(path, headers=auth)).status_code == 200
        return queries.count

    async def add_goal(i: int) -> None:
        g = await _mk(
            client, auth, "goals", {"name": f"G{i}", "target_amount": "100", "currency": "COP"}
        )
        await _mk(
            client, auth, f"goals/{g['id']}/contributions", {"amount": "5", "occurred_on": today}
        )

    async def add_budget(i: int) -> None:
        cat = await _mk(client, auth, "categories", {"name": f"C{i}", "kind": "expense"})
        await _mk(
            client, auth, "budgets", {"category_id": cat["id"], "month": today, "amount": "100"}
        )
        await _mk(
            client,
            auth,
            "transactions",
            {
                "type": "expense",
                "account_id": acc["id"],
                "category_id": cat["id"],
                "amount": "7",
                "occurred_on": today,
            },
        )

    await add_goal(0)
    await add_budget(0)
    few_goals, few_budgets = (
        await count("/api/v1/goals"),
        await count(f"/api/v1/budgets?month={today}"),
    )
    for i in range(1, 8):
        await add_goal(i)
        await add_budget(i)
    assert await count("/api/v1/goals") == few_goals
    assert await count(f"/api/v1/budgets?month={today}") == few_budgets
    budgets = (await client.get(f"/api/v1/budgets?month={today}", headers=auth)).json()
    assert len(budgets) == 8 and {b["spent"] for b in budgets} == {"7.00"}


# ---- propiedades del dinero (hypothesis) ------------------------------------
amounts = st.decimals(min_value=Decimal("0.01"), max_value=Decimal("100000"), places=2)
ops = st.lists(
    st.tuples(
        st.sampled_from(["income", "expense", "transfer_ab", "transfer_ba"]),
        amounts,
        st.integers(0, 60),
    ),
    min_size=1,
    max_size=25,
)


@pytest.mark.parametrize("seed_initial", [Decimal("0"), Decimal("1234.56"), Decimal("-50.25")])
@settings(
    max_examples=15, deadline=None, suppress_health_check=[HealthCheck.function_scoped_fixture]
)
@given(operations=ops)
async def test_balances_always_equal_initial_plus_movements(
    client: AsyncClient, auth: H, seed_initial: Decimal, operations: list[tuple[str, Decimal, int]]
) -> None:
    """Invariante: saldo = inicial + ingresos − gastos ± transferencias entre cuentas."""
    suffix = str(abs(hash(str(operations))) % 10**8)
    a = await _mk(
        client,
        auth,
        "accounts",
        {
            "name": f"A{suffix}",
            "type": "bank",
            "currency": "COP",
            "initial_balance": str(seed_initial),
        },
    )
    b = await _mk(
        client,
        auth,
        "accounts",
        {"name": f"B{suffix}", "type": "bank", "currency": "COP", "initial_balance": "0"},
    )
    base = date(2026, 1, 1)
    exp_a, exp_b = seed_initial, Decimal("0")
    for kind, amount, day in operations:
        when = (base + timedelta(days=day)).isoformat()
        body: dict[str, object] = {"amount": str(amount), "occurred_on": when}
        if kind == "income":
            body |= {"type": "income", "account_id": a["id"]}
            exp_a += amount
        elif kind == "expense":
            body |= {"type": "expense", "account_id": a["id"]}
            exp_a -= amount
        elif kind == "transfer_ab":
            body |= {"type": "transfer", "account_id": a["id"], "transfer_account_id": b["id"]}
            exp_a -= amount
            exp_b += amount
        else:
            body |= {"type": "transfer", "account_id": b["id"], "transfer_account_id": a["id"]}
            exp_b -= amount
            exp_a += amount
        await _mk(client, auth, "transactions", body)
    got = {
        x["id"]: Decimal(x["balance"])
        for x in (await client.get("/api/v1/accounts", headers=auth)).json()
    }
    assert got[a["id"]] == exp_a
    assert got[b["id"]] == exp_b
