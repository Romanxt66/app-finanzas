"""Sala de espera: el usuario aparca una compra, la app le pide esperar y, al decidir no
comprarla, suma ese dinero a «lo que no gastaste»."""

import uuid
from collections import defaultdict
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFoundError
from app.models import WaitingItem, WaitingStatus
from app.schemas.waiting_room import (
    Decision,
    SavedTotal,
    WaitingCreate,
    WaitingOut,
    WaitingRoom,
)

HISTORY_LIMIT = 50  # decididas más recientes que se devuelven


def _aware(moment: datetime) -> datetime:
    # SQLite devuelve fechas sin zona; se guardan siempre en UTC
    return moment if moment.tzinfo else moment.replace(tzinfo=UTC)


def to_out(item: WaitingItem, now: datetime) -> WaitingOut:
    ready = item.status == WaitingStatus.waiting and _aware(item.ready_at) <= now
    return WaitingOut(
        id=item.id,
        created_at=item.created_at,
        name=item.name,
        amount=item.amount,
        currency=item.currency,
        wait_hours=item.wait_hours,
        ready_at=_aware(item.ready_at),
        status=WaitingStatus(item.status),
        decided_at=_aware(item.decided_at) if item.decided_at else None,
        ready=ready,
    )


def summarize(items: list[WaitingItem], now: datetime) -> WaitingRoom:
    outs = [to_out(i, now) for i in items]
    not_spent: dict[str, Decimal] = defaultdict(Decimal)
    for i in items:
        if i.status == WaitingStatus.skipped:
            not_spent[i.currency] += i.amount
    pending = [o for o in outs if o.status == WaitingStatus.waiting]
    decided = [o for o in outs if o.status != WaitingStatus.waiting]
    pending.sort(key=lambda o: o.ready_at)
    decided.sort(key=lambda o: o.decided_at or o.created_at, reverse=True)
    return WaitingRoom(
        items=pending + decided[:HISTORY_LIMIT],
        waiting=len(pending),
        ready=sum(1 for o in pending if o.ready),
        skipped=sum(1 for o in outs if o.status == WaitingStatus.skipped),
        bought=sum(1 for o in outs if o.status == WaitingStatus.bought),
        not_spent=[SavedTotal(currency=c, total=t) for c, t in sorted(not_spent.items())],
    )


async def _owned(session: AsyncSession, user_id: uuid.UUID, item_id: uuid.UUID) -> WaitingItem:
    item = await session.get(WaitingItem, item_id)
    if item is None or item.user_id != user_id:
        raise NotFoundError("Compra en espera no encontrada")
    return item


async def room(session: AsyncSession, user_id: uuid.UUID, now: datetime) -> WaitingRoom:
    rows = await session.scalars(select(WaitingItem).where(WaitingItem.user_id == user_id))
    return summarize(list(rows.all()), now)


async def create(
    session: AsyncSession, user_id: uuid.UUID, data: WaitingCreate, now: datetime
) -> WaitingOut:
    item = WaitingItem(
        user_id=user_id,
        name=data.name.strip(),
        amount=data.amount,
        currency=data.currency,
        wait_hours=data.wait_hours,
        ready_at=now + timedelta(hours=data.wait_hours),
        status=WaitingStatus.waiting,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return to_out(item, now)


async def decide(
    session: AsyncSession, user_id: uuid.UUID, item_id: uuid.UUID, decision: Decision, now: datetime
) -> WaitingOut:
    item = await _owned(session, user_id, item_id)
    if item.status != WaitingStatus.waiting:
        raise AppError("Esta compra ya tiene una decisión")
    item.status = WaitingStatus(decision.value)
    item.decided_at = now
    await session.commit()
    await session.refresh(item)
    return to_out(item, now)


async def delete(session: AsyncSession, user_id: uuid.UUID, item_id: uuid.UUID) -> None:
    item = await _owned(session, user_id, item_id)
    await session.delete(item)
    await session.commit()
