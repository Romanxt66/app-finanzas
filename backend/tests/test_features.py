from decimal import Decimal

import pytest
from httpx import AsyncClient

from app.core.ratelimit import FailureLimiter
from tests.conftest import register_and_login

H = dict[str, str]


async def _mk(c: AsyncClient, h: H, path: str, body: dict[str, object]) -> dict[str, str]:
    r = await c.post(f"/api/v1/{path}", headers=h, json=body)
    assert r.status_code == 201, r.text
    return dict(r.json())


# ---- metas de ahorro --------------------------------------------------------
async def _goal(c: AsyncClient, h: H, target: str = "1000") -> dict[str, str]:
    return await _mk(c, h, "goals", {"name": "Viaje", "target_amount": target, "currency": "cop"})


async def test_goal_progress_and_achievement(client: AsyncClient, auth: H) -> None:
    goal = await _goal(client, auth)
    assert goal["currency"] == "COP" and goal["saved"] == "0.00"
    for amount in ("300.50", "200"):
        await _mk(
            client,
            auth,
            f"goals/{goal['id']}/contributions",
            {"amount": amount, "occurred_on": "2026-03-01"},
        )
    g = (await client.get("/api/v1/goals", headers=auth)).json()[0]
    assert (g["saved"], g["remaining"], g["achieved"]) == ("500.50", "499.50", False)
    await _mk(
        client,
        auth,
        f"goals/{goal['id']}/contributions",
        {"amount": "600", "occurred_on": "2026-03-02"},
    )
    g = (await client.get("/api/v1/goals", headers=auth)).json()[0]
    assert g["achieved"] is True and Decimal(g["remaining"]) == 0  # nunca negativo


async def test_goal_withdrawals_cannot_go_negative(client: AsyncClient, auth: H) -> None:
    goal = await _goal(client, auth)
    url = f"/api/v1/goals/{goal['id']}/contributions"
    await _mk(
        client,
        auth,
        f"goals/{goal['id']}/contributions",
        {"amount": "100", "occurred_on": "2026-03-01"},
    )
    over = await client.post(
        url, headers=auth, json={"amount": "-150", "occurred_on": "2026-03-02"}
    )
    assert over.status_code == 400
    ok = await client.post(url, headers=auth, json={"amount": "-40", "occurred_on": "2026-03-02"})
    assert ok.status_code == 201
    zero = await client.post(url, headers=auth, json={"amount": "0", "occurred_on": "2026-03-02"})
    assert zero.status_code == 422


async def test_goal_update_delete_and_contribution_delete(client: AsyncClient, auth: H) -> None:
    goal = await _goal(client, auth)
    c1 = await _mk(
        client,
        auth,
        f"goals/{goal['id']}/contributions",
        {"amount": "100", "occurred_on": "2026-03-01", "note": "ahorro"},
    )
    c2 = await _mk(
        client,
        auth,
        f"goals/{goal['id']}/contributions",
        {"amount": "-30", "occurred_on": "2026-03-02"},
    )
    # borrar el aporte de 100 dejaría -30: se rechaza; borrar el retiro sí se puede
    blocked = await client.delete(
        f"/api/v1/goals/{goal['id']}/contributions/{c1['id']}", headers=auth
    )
    assert blocked.status_code == 400
    assert (
        await client.delete(f"/api/v1/goals/{goal['id']}/contributions/{c2['id']}", headers=auth)
    ).status_code == 204
    upd = await client.patch(
        f"/api/v1/goals/{goal['id']}",
        headers=auth,
        json={"name": "Vacaciones", "target_amount": "2000", "deadline": "2027-01-01"},
    )
    body = upd.json()
    assert (body["name"], body["target_amount"], body["deadline"]) == (
        "Vacaciones",
        "2000.00",
        "2027-01-01",
    )
    contribs = (await client.get(f"/api/v1/goals/{goal['id']}/contributions", headers=auth)).json()
    assert [c["note"] for c in contribs] == ["ahorro"]
    assert (await client.delete(f"/api/v1/goals/{goal['id']}", headers=auth)).status_code == 204
    assert (await client.get("/api/v1/goals", headers=auth)).json() == []


async def test_goals_are_private_and_validated(client: AsyncClient, auth: H) -> None:
    goal = await _goal(client, auth)
    other = await register_and_login(client, "b@example.com")
    assert (await client.get("/api/v1/goals", headers=other)).json() == []
    assert (
        await client.patch(f"/api/v1/goals/{goal['id']}", headers=other, json={"name": "x"})
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/goals/{goal['id']}/contributions",
            headers=other,
            json={"amount": "5", "occurred_on": "2026-03-01"},
        )
    ).status_code == 404
    bad = await client.post(
        "/api/v1/goals", headers=auth, json={"name": "X", "target_amount": "0", "currency": "COP"}
    )
    assert bad.status_code == 422


# ---- eliminar cuentas -------------------------------------------------------
async def test_delete_account_rules(client: AsyncClient, auth: H) -> None:
    empty = await _mk(
        client,
        auth,
        "accounts",
        {"name": "Vacía", "type": "cash", "currency": "COP", "initial_balance": "0"},
    )
    used = await _mk(
        client,
        auth,
        "accounts",
        {"name": "Usada", "type": "cash", "currency": "COP", "initial_balance": "0"},
    )
    other = await _mk(
        client,
        auth,
        "accounts",
        {"name": "Otra", "type": "cash", "currency": "COP", "initial_balance": "0"},
    )
    await _mk(
        client,
        auth,
        "transactions",
        {
            "type": "transfer",
            "account_id": used["id"],
            "transfer_account_id": other["id"],
            "amount": "5",
            "occurred_on": "2026-03-01",
        },
    )
    assert (await client.delete(f"/api/v1/accounts/{empty['id']}", headers=auth)).status_code == 204
    for acc in (used, other):  # origen y destino de una transferencia
        r = await client.delete(f"/api/v1/accounts/{acc['id']}", headers=auth)
        assert r.status_code == 409 and "archívala" in r.json()["error"]["message"]
    intruder = await register_and_login(client, "b@example.com")
    assert (
        await client.delete(f"/api/v1/accounts/{used['id']}", headers=intruder)
    ).status_code == 404


# ---- exportación CSV --------------------------------------------------------
async def test_csv_export(client: AsyncClient, auth: H) -> None:
    acc = await _mk(
        client,
        auth,
        "accounts",
        {"name": "=HYPERLINK(1)", "type": "bank", "currency": "COP", "initial_balance": "0"},
    )
    cat = await _mk(client, auth, "categories", {"name": "Comida, fuera", "kind": "expense"})
    await _mk(
        client,
        auth,
        "transactions",
        {
            "type": "expense",
            "account_id": acc["id"],
            "category_id": cat["id"],
            "amount": "12.5",
            "occurred_on": "2026-03-05",
            "description": '+cmd "x"',
        },
    )
    await _mk(
        client,
        auth,
        "transactions",
        {
            "type": "income",
            "account_id": acc["id"],
            "amount": "100",
            "occurred_on": "2026-04-05",
            "description": "Pago",
        },
    )
    resp = await client.get("/api/v1/transactions/export", headers=auth)
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/csv")
    assert "attachment" in resp.headers["content-disposition"]
    text = resp.content.decode("utf-8")
    assert text.startswith("﻿")  # BOM para Excel
    lines = text.lstrip("﻿").splitlines()
    assert lines[0] == "fecha,tipo,cuenta,cuenta_destino,categoria,descripcion,monto,moneda"
    assert lines[1].startswith("2026-04-05,ingreso,")  # más reciente primero
    assert "'=HYPERLINK(1)" in text and "'+cmd" in text  # sin inyección de fórmulas
    assert '"Comida, fuera"' in text  # comas escapadas
    filtered = await client.get("/api/v1/transactions/export?type=expense", headers=auth)
    assert len(filtered.text.lstrip("﻿").splitlines()) == 2


async def test_csv_export_only_own_data(client: AsyncClient, auth: H) -> None:
    acc = await _mk(
        client,
        auth,
        "accounts",
        {"name": "Mía", "type": "bank", "currency": "COP", "initial_balance": "0"},
    )
    await _mk(
        client,
        auth,
        "transactions",
        {"type": "income", "account_id": acc["id"], "amount": "9", "occurred_on": "2026-03-05"},
    )
    other = await register_and_login(client, "b@example.com")
    resp = await client.get("/api/v1/transactions/export", headers=other)
    assert len(resp.text.lstrip("﻿").splitlines()) == 1  # solo cabecera
    assert (await client.get("/api/v1/transactions/export")).status_code == 401


# ---- perfil y contraseña ----------------------------------------------------
async def test_update_profile(client: AsyncClient, auth: H) -> None:
    r = await client.patch("/api/v1/auth/me", headers=auth, json={"full_name": "Nuevo Nombre"})
    assert r.json()["full_name"] == "Nuevo Nombre"
    assert (await client.get("/api/v1/auth/me", headers=auth)).json()["full_name"] == "Nuevo Nombre"
    assert (
        await client.patch("/api/v1/auth/me", headers=auth, json={"full_name": ""})
    ).status_code == 422


async def test_change_password(client: AsyncClient, auth: H) -> None:
    url = "/api/v1/auth/change-password"
    wrong = await client.post(
        url, headers=auth, json={"current_password": "incorrecta1", "new_password": "NuevaClave-99"}
    )
    assert wrong.status_code == 400 and "actual es incorrecta" in wrong.json()["error"]["message"]
    same = await client.post(
        url, headers=auth, json={"current_password": "password-123", "new_password": "password-123"}
    )
    assert same.status_code == 400 and "distinta" in same.json()["error"]["message"]
    weak = await client.post(
        url, headers=auth, json={"current_password": "password-123", "new_password": "corta"}
    )
    assert weak.status_code == 422 and "al menos 8" in weak.json()["error"]["message"]
    ok = await client.post(
        url,
        headers=auth,
        json={"current_password": "password-123", "new_password": "NuevaClave-99"},
    )
    assert ok.status_code == 204
    old = await client.post(
        "/api/v1/auth/login", json={"email": "a@example.com", "password": "password-123"}
    )
    assert old.status_code == 401
    new = await client.post(
        "/api/v1/auth/login", json={"email": "a@example.com", "password": "NuevaClave-99"}
    )
    assert new.status_code == 200


# ---- límite de intentos de login --------------------------------------------
class _Clock:
    now = 1000.0

    def __call__(self) -> float:
        return self.now


def test_limiter_blocks_and_expires() -> None:
    clock = _Clock()
    limiter = FailureLimiter(max_failures=3, window_seconds=60, clock=clock)
    for _ in range(2):
        limiter.record_failure("k")
    assert limiter.retry_after("k") == 0
    limiter.record_failure("k")
    assert 0 < limiter.retry_after("k") <= 61
    assert limiter.retry_after("otra-clave") == 0
    clock.now += 61
    assert limiter.retry_after("k") == 0  # la ventana expiró


def test_limiter_reset_on_success() -> None:
    limiter = FailureLimiter(max_failures=2, window_seconds=60, clock=_Clock())
    limiter.record_failure("k")
    limiter.record_failure("k")
    assert limiter.retry_after("k") > 0
    limiter.reset("k")
    assert limiter.retry_after("k") == 0


async def test_login_is_rate_limited(client: AsyncClient) -> None:
    await register_and_login(client)
    bad = {"email": "a@example.com", "password": "incorrecta1"}
    for _ in range(5):
        assert (await client.post("/api/v1/auth/login", json=bad)).status_code == 401
    blocked = await client.post("/api/v1/auth/login", json=bad)
    assert blocked.status_code == 429 and blocked.json()["error"]["code"] == "too_many_requests"
    # incluso con la contraseña correcta mientras dura el bloqueo
    good = await client.post(
        "/api/v1/auth/login", json={"email": "a@example.com", "password": "password-123"}
    )
    assert good.status_code == 429
    # otro correo no queda bloqueado
    other = await client.post(
        "/api/v1/auth/login", json={"email": "b@example.com", "password": "x"}
    )
    assert other.status_code == 401


async def test_login_limit_also_per_email_when_ip_varies(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Rotar la IP (cabecera X-Forwarded-For falsificada) no evita el límite por correo."""
    from app.api.v1.auth import login_limiter

    monkeypatch.setattr(login_limiter, "max_failures", 10_000)  # solo actúa el límite por correo
    await register_and_login(client)
    for i in range(20):
        r = await client.post(
            "/api/v1/auth/login",
            json={"email": "a@example.com", "password": "incorrecta1"},
            headers={"X-Forwarded-For": f"10.0.0.{i}"},
        )
        assert r.status_code == 401
    final = await client.post(
        "/api/v1/auth/login", json={"email": "a@example.com", "password": "password-123"}
    )
    assert final.status_code == 429


@pytest.mark.parametrize("path", ["/api/v1/goals", "/api/v1/transactions/export"])
async def test_new_endpoints_require_auth(client: AsyncClient, path: str) -> None:
    assert (await client.get(path)).status_code == 401
