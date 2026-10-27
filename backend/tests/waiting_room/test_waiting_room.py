import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from httpx import AsyncClient

from app.models import WaitingItem, WaitingStatus
from app.services.waiting_room import summarize
from tests.conftest import register_and_login

H = dict[str, str]
NOW = datetime(2026, 10, 27, 12, tzinfo=UTC)


def item(name: str, amount: str, status: WaitingStatus, hours_left: int, currency: str = "EUR"):
    return WaitingItem(
        id=uuid.uuid4(),
        name=name,
        amount=Decimal(amount),
        currency=currency,
        wait_hours=72,
        ready_at=NOW + timedelta(hours=hours_left),
        status=status,
        decided_at=NOW if status != WaitingStatus.waiting else None,
        created_at=NOW - timedelta(hours=72 - hours_left),
    )


def test_summary_counts_ready_and_not_spent() -> None:
    room = summarize(
        [
            item("Auriculares", "89.90", WaitingStatus.waiting, 5),
            item("Zapatillas", "120", WaitingStatus.waiting, -1),
            item("Chaqueta", "60", WaitingStatus.skipped, 0),
            item("Libro", "15", WaitingStatus.skipped, 0, currency="USD"),
            item("Cable", "9", WaitingStatus.bought, 0),
        ],
        NOW,
    )
    assert (room.waiting, room.ready, room.skipped, room.bought) == (2, 1, 2, 1)
    assert [i.name for i in room.items[:2]] == ["Zapatillas", "Auriculares"]
    assert room.items[0].ready and not room.items[1].ready
    assert [(t.currency, t.total) for t in room.not_spent] == [
        ("EUR", Decimal("60")),
        ("USD", Decimal("15")),
    ]


async def test_waiting_room_flow(client: AsyncClient, auth: H) -> None:
    r = await client.post(
        "/api/v1/waiting-room",
        headers=auth,
        json={"name": "Auriculares", "amount": "89.90", "currency": "eur"},
    )
    assert r.status_code == 201, r.text
    created = r.json()
    assert created["currency"] == "EUR"
    assert created["wait_hours"] == 72
    assert created["status"] == "waiting"
    assert created["ready"] is False

    room = (await client.get("/api/v1/waiting-room", headers=auth)).json()
    assert room["waiting"] == 1

    r = await client.post(
        f"/api/v1/waiting-room/{created['id']}/decide", headers=auth, json={"decision": "skipped"}
    )
    assert r.json()["status"] == "skipped"
    again = await client.post(
        f"/api/v1/waiting-room/{created['id']}/decide", headers=auth, json={"decision": "bought"}
    )
    assert again.status_code == 400

    room = (await client.get("/api/v1/waiting-room", headers=auth)).json()
    assert room["not_spent"] == [{"currency": "EUR", "total": "89.90"}]

    other = await register_and_login(client, "b@example.com")
    assert (await client.get("/api/v1/waiting-room", headers=other)).json()["items"] == []
    r = await client.delete(f"/api/v1/waiting-room/{created['id']}", headers=other)
    assert r.status_code == 404
    r = await client.delete(f"/api/v1/waiting-room/{created['id']}", headers=auth)
    assert r.status_code == 204


async def test_waiting_room_validation(client: AsyncClient, auth: H) -> None:
    for body in (
        {"name": "", "amount": "10", "currency": "EUR"},
        {"name": "X", "amount": "0", "currency": "EUR"},
        {"name": "X", "amount": "10", "currency": "XXX"},
        {"name": "X", "amount": "10", "currency": "EUR", "wait_hours": 0},
        {"name": "X", "amount": "10", "currency": "EUR", "wait_hours": 721},
    ):
        r = await client.post("/api/v1/waiting-room", headers=auth, json=body)
        assert r.status_code == 422, body
