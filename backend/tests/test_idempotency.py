from httpx import AsyncClient

from tests.conftest import register_and_login


async def _account(client: AsyncClient, headers: dict[str, str]) -> str:
    resp = await client.post(
        "/api/v1/accounts",
        json={"name": "Banco", "type": "bank", "currency": "COP", "initial_balance": "0"},
        headers=headers,
    )
    return str(resp.json()["id"])


def _tx(account_id: str) -> dict[str, str]:
    return {
        "type": "expense",
        "account_id": account_id,
        "amount": "12000",
        "description": "Café",
        "occurred_on": "2026-11-10",
    }


async def test_reenviar_con_la_misma_clave_no_duplica(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    account = await _account(client, headers)
    keyed = {**headers, "Idempotency-Key": "offline-0001-abcdef"}

    first = await client.post("/api/v1/transactions", json=_tx(account), headers=keyed)
    again = await client.post("/api/v1/transactions", json=_tx(account), headers=keyed)

    assert first.status_code == 201
    assert again.status_code == 201
    assert again.json()["id"] == first.json()["id"]
    assert again.headers.get("idempotent-replayed") == "true"
    page = (await client.get("/api/v1/transactions", headers=headers)).json()
    assert page["total"] == 1


async def test_sin_clave_cada_envio_cuenta(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    account = await _account(client, headers)
    await client.post("/api/v1/transactions", json=_tx(account), headers=headers)
    await client.post("/api/v1/transactions", json=_tx(account), headers=headers)
    page = (await client.get("/api/v1/transactions", headers=headers)).json()
    assert page["total"] == 2


async def test_la_clave_es_de_cada_usuario(client: AsyncClient) -> None:
    ana = await register_and_login(client, "ana@example.com")
    leo = await register_and_login(client, "leo@example.com")
    key = {"Idempotency-Key": "shared-key-12345"}
    a = await client.post(
        "/api/v1/transactions", json=_tx(await _account(client, ana)), headers={**ana, **key}
    )
    b = await client.post(
        "/api/v1/transactions", json=_tx(await _account(client, leo)), headers={**leo, **key}
    )
    assert a.status_code == b.status_code == 201
    assert a.json()["id"] != b.json()["id"]
    assert "idempotent-replayed" not in b.headers


async def test_misma_clave_para_otro_cambio_es_un_conflicto(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    account = await _account(client, headers)
    keyed = {**headers, "Idempotency-Key": "offline-0002-abcdef"}
    await client.post("/api/v1/transactions", json=_tx(account), headers=keyed)
    resp = await client.patch(f"/api/v1/accounts/{account}", json={"name": "Otro"}, headers=keyed)
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "idempotency_conflict"


async def test_un_error_no_se_recuerda(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    keyed = {**headers, "Idempotency-Key": "offline-0003-abcdef"}
    bad = await client.post("/api/v1/transactions", json={"type": "expense"}, headers=keyed)
    assert bad.status_code == 422
    account = await _account(client, headers)
    ok = await client.post("/api/v1/transactions", json=_tx(account), headers=keyed)
    assert ok.status_code == 201


async def test_borrar_repetido_responde_igual(client: AsyncClient) -> None:
    headers = await register_and_login(client)
    account = await _account(client, headers)
    tx = (await client.post("/api/v1/transactions", json=_tx(account), headers=headers)).json()
    keyed = {**headers, "Idempotency-Key": "offline-0004-abcdef"}
    first = await client.delete(f"/api/v1/transactions/{tx['id']}", headers=keyed)
    again = await client.delete(f"/api/v1/transactions/{tx['id']}", headers=keyed)
    assert first.status_code == again.status_code == 204
