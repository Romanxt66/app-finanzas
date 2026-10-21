import pytest
from httpx import AsyncClient

from tests.conftest import register_and_login

H = dict[str, str]
URL = "/api/v1/transactions/bulk"


async def _mk(c: AsyncClient, h: H, path: str, body: dict[str, object]) -> dict[str, str]:
    r = await c.post(f"/api/v1/{path}", headers=h, json=body)
    assert r.status_code == 201, r.text
    return dict(r.json())


async def _account(c: AsyncClient, h: H) -> str:
    return (
        await _mk(
            c,
            h,
            "accounts",
            {"name": "Banco", "type": "bank", "currency": "COP", "initial_balance": "1000"},
        )
    )["id"]


def _item(day: str, amount: str, description: str = "", **extra: object) -> dict[str, object]:
    return {"occurred_on": day, "amount": amount, "description": description, **extra}


async def test_import_signed_amounts_and_balance(client: AsyncClient, auth: H) -> None:
    acc = await _account(client, auth)
    res = await client.post(
        URL,
        headers=auth,
        json={
            "account_id": acc,
            "items": [
                _item("2026-03-05", "-186400.50", "Supermercado"),
                _item("2026-03-06", "4850000", "Nómina"),
            ],
        },
    )
    assert res.status_code == 200 and res.json() == {"created": 2, "skipped": 0}
    txs = {
        t["description"]: t
        for t in (await client.get("/api/v1/transactions", headers=auth)).json()["items"]
    }
    assert (txs["Supermercado"]["type"], txs["Supermercado"]["amount"]) == ("expense", "186400.50")
    assert (txs["Nómina"]["type"], txs["Nómina"]["amount"]) == ("income", "4850000.00")
    balance = (await client.get(f"/api/v1/accounts/{acc}", headers=auth)).json()["balance"]
    assert balance == "4664599.50"  # 1000 − 186400.50 + 4850000


async def test_reimport_skips_existing_but_keeps_repeated_rows(
    client: AsyncClient, auth: H
) -> None:
    acc = await _account(client, auth)
    file = [
        _item("2026-03-05", "-5", "Café"),
        _item("2026-03-05", "-5", "Café"),
        _item("2026-03-06", "-7", "Taxi"),
    ]
    first = await client.post(URL, headers=auth, json={"account_id": acc, "items": file})
    assert first.json() == {"created": 3, "skipped": 0}  # dos cafés idénticos son dos movimientos
    again = await client.post(URL, headers=auth, json={"account_id": acc, "items": file})
    assert again.json() == {"created": 0, "skipped": 3}  # idempotente
    extra = await client.post(
        URL,
        headers=auth,
        json={"account_id": acc, "items": [*file, _item("2026-03-07", "-9", "Nuevo")]},
    )
    assert extra.json() == {"created": 1, "skipped": 3}
    forced = await client.post(
        URL, headers=auth, json={"account_id": acc, "items": file[:1], "skip_duplicates": False}
    )
    assert forced.json() == {"created": 1, "skipped": 0}
    assert (await client.get("/api/v1/transactions?limit=50", headers=auth)).json()["total"] == 5


async def test_category_must_match_sign(client: AsyncClient, auth: H) -> None:
    acc = await _account(client, auth)
    food = await _mk(client, auth, "categories", {"name": "Comida", "kind": "expense"})
    ok = await client.post(
        URL,
        headers=auth,
        json={"account_id": acc, "items": [_item("2026-03-05", "-5", "x", category_id=food["id"])]},
    )
    assert ok.status_code == 200
    bad = await client.post(
        URL,
        headers=auth,
        json={
            "account_id": acc,
            "items": [_item("2026-03-05", "-5"), _item("2026-03-06", "10", category_id=food["id"])],
        },
    )
    assert bad.status_code == 400 and "Fila 2" in bad.json()["error"]["message"]
    # nada se guardó parcialmente
    assert (await client.get("/api/v1/transactions", headers=auth)).json()["total"] == 1


async def test_validation_limits(client: AsyncClient, auth: H) -> None:
    acc = await _account(client, auth)
    assert (
        await client.post(URL, headers=auth, json={"account_id": acc, "items": []})
    ).status_code == 422
    assert (
        await client.post(
            URL, headers=auth, json={"account_id": acc, "items": [_item("2026-03-05", "0")]}
        )
    ).status_code == 422
    too_many = [_item("2026-03-05", "-1", str(i)) for i in range(1001)]
    assert (
        await client.post(URL, headers=auth, json={"account_id": acc, "items": too_many})
    ).status_code == 422
    assert (
        await client.post(
            URL, headers=auth, json={"account_id": acc, "items": [_item("fecha", "5")]}
        )
    ).status_code == 422
    ok = [_item("2026-03-05", "-1", str(i)) for i in range(1000)]
    assert (await client.post(URL, headers=auth, json={"account_id": acc, "items": ok})).json()[
        "created"
    ] == 1000


async def test_import_is_private(client: AsyncClient, auth: H) -> None:
    acc = await _account(client, auth)
    other = await register_and_login(client, "b@example.com")
    res = await client.post(
        URL, headers=other, json={"account_id": acc, "items": [_item("2026-03-05", "5")]}
    )
    assert res.status_code == 404
    assert (
        await client.post(URL, json={"account_id": acc, "items": [_item("2026-03-05", "5")]})
    ).status_code == 401


@pytest.mark.parametrize("amount", ["1.234", "abc", None])
async def test_rejects_bad_amounts(client: AsyncClient, auth: H, amount: object) -> None:
    acc = await _account(client, auth)
    res = await client.post(
        URL,
        headers=auth,
        json={"account_id": acc, "items": [{"occurred_on": "2026-03-05", "amount": amount}]},
    )
    assert res.status_code == 422
