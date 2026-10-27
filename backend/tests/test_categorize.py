from httpx import AsyncClient

from app.services.categorize import normalize, tokens

H = dict[str, str]
URL = "/api/v1/transactions/categorize"


async def _mk(c: AsyncClient, h: H, path: str, body: dict[str, object]) -> dict[str, str]:
    r = await c.post(f"/api/v1/{path}", headers=h, json=body)
    assert r.status_code == 201, r.text
    return dict(r.json())


def test_normalize_drops_accents_numbers_and_symbols() -> None:
    assert normalize("COMPRA  Éxito #1234 - Bogotá") == "compra exito bogota"
    assert tokens("PAGO PSE Netflix.com 0099") == ["netflix"]


async def test_history_beats_keywords(client: AsyncClient, auth: H) -> None:
    acc = await _mk(
        client,
        auth,
        "accounts",
        {"name": "Nequi", "type": "bank", "currency": "COP", "initial_balance": "0"},
    )
    super_ = await _mk(client, auth, "categories", {"name": "Supermercado", "kind": "expense"})
    subs = await _mk(client, auth, "categories", {"name": "suscripciones", "kind": "expense"})
    gifts = await _mk(client, auth, "categories", {"name": "Regalos", "kind": "expense"})
    salary = await _mk(client, auth, "categories", {"name": "Nómina", "kind": "income"})
    for desc, cat in [("Tienda Doña Rosa", gifts["id"]), ("Tienda Doña Rosa", gifts["id"])]:
        await _mk(
            client,
            auth,
            "transactions",
            {
                "type": "expense",
                "account_id": acc["id"],
                "category_id": cat,
                "amount": "1000",
                "description": desc,
                "occurred_on": "2026-01-01",
            },
        )

    r = await client.post(
        URL,
        headers=auth,
        json={
            "items": [
                {"description": "Tienda doña rosa", "amount": "-5000"},
                {"description": "COMPRA DOÑA ROSA 0042", "amount": "-5000"},
                {"description": "Compra EXITO Calle 80", "amount": "-120000"},
                {"description": "NETFLIX.COM", "amount": "-44900"},
                {"description": "Pago nómina octubre", "amount": "3500000"},
                {"description": "Nómina", "amount": "-10"},  # gasto: no es una nómina
                {"description": "Algo raro", "amount": "-10"},
                {"description": "", "amount": "-10"},
            ]
        },
    )
    assert r.status_code == 200, r.text
    got = [(s["category_id"], s["source"]) for s in r.json()["suggestions"]]
    assert got == [
        (gifts["id"], "history"),
        (gifts["id"], "history"),
        (super_["id"], "keyword"),
        (subs["id"], "keyword"),
        (salary["id"], "keyword"),
        (None, None),
        (None, None),
        (None, None),
    ]


async def test_keyword_needs_a_matching_user_category(client: AsyncClient, auth: H) -> None:
    r = await client.post(
        URL, headers=auth, json={"items": [{"description": "Uber trip", "amount": "-9000"}]}
    )
    assert r.json()["suggestions"] == [{"category_id": None, "source": None}]
