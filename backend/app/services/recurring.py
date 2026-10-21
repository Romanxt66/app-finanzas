import calendar
import uuid
from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.models import Frequency, RecurringRule, Transaction
from app.schemas.recurring import RecurringCreate, RecurringUpdate
from app.schemas.transaction import TransactionCreate
from app.services import transactions

MAX_CATCH_UP = 120  # tope de ocurrencias atrasadas por regla y ejecución


def _clamped(year: int, month: int, day: int) -> date:
    return date(year, month, min(day, calendar.monthrange(year, month)[1]))


def _next_month(current: date, anchor_day: int) -> date:
    year, month = (
        (current.year + 1, 1) if current.month == 12 else (current.year, current.month + 1)
    )
    return _clamped(year, month, anchor_day)


def advance(rule: RecurringRule) -> date:
    """Siguiente ocurrencia después de `next_date`, respetando el día de inicio (ancla)."""
    current = rule.next_date
    if rule.frequency == Frequency.weekly:
        return current + timedelta(days=7)
    if rule.frequency == Frequency.monthly:
        return _next_month(current, rule.anchor_day)
    return _clamped(current.year + 1, rule.anchor_month, rule.anchor_day)


async def get_owned(session: AsyncSession, user_id: uuid.UUID, rule_id: uuid.UUID) -> RecurringRule:
    rule = await session.get(RecurringRule, rule_id)
    if rule is None or rule.user_id != user_id:
        raise NotFoundError("Regla recurrente no encontrada")
    return rule


async def list_rules(session: AsyncSession, user_id: uuid.UUID) -> list[RecurringRule]:
    stmt = (
        select(RecurringRule)
        .where(RecurringRule.user_id == user_id)
        .order_by(RecurringRule.active.desc(), RecurringRule.next_date)
    )
    return list((await session.scalars(stmt)).all())


async def create_rule(
    session: AsyncSession, user_id: uuid.UUID, data: RecurringCreate
) -> RecurringRule:
    # Misma validación de cuentas/categoría que un movimiento normal
    await transactions.validate(
        session,
        user_id,
        TransactionCreate(
            type=data.type,
            account_id=data.account_id,
            transfer_account_id=data.transfer_account_id,
            category_id=data.category_id,
            amount=data.amount,
            description=data.description,
            occurred_on=data.start_date,
        ),
    )
    rule = RecurringRule(
        user_id=user_id,
        type=data.type,
        account_id=data.account_id,
        transfer_account_id=data.transfer_account_id,
        category_id=data.category_id,
        amount=data.amount,
        description=data.description,
        frequency=data.frequency,
        anchor_day=data.start_date.day,
        anchor_month=data.start_date.month,
        next_date=data.start_date,
        end_date=data.end_date,
    )
    session.add(rule)
    await session.commit()
    await session.refresh(rule)
    return rule


async def update_rule(
    session: AsyncSession, user_id: uuid.UUID, rule_id: uuid.UUID, data: RecurringUpdate
) -> RecurringRule:
    rule = await get_owned(session, user_id, rule_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(rule, field, value)
    await session.commit()
    return rule


async def delete_rule(session: AsyncSession, user_id: uuid.UUID, rule_id: uuid.UUID) -> None:
    rule = await get_owned(session, user_id, rule_id)
    await session.delete(rule)
    await session.commit()


async def run_due(session: AsyncSession, user_id: uuid.UUID, today: date) -> int:
    """Crea los movimientos vencidos (next_date <= hoy). Idempotente: avanza next_date."""
    rules = (
        await session.scalars(
            select(RecurringRule).where(
                RecurringRule.user_id == user_id,
                RecurringRule.active.is_(True),
                RecurringRule.next_date <= today,
            )
        )
    ).all()
    created = 0
    for rule in rules:
        steps = 0
        while rule.next_date <= today and steps < MAX_CATCH_UP:
            if rule.end_date is not None and rule.next_date > rule.end_date:
                rule.active = False
                break
            session.add(
                Transaction(
                    user_id=user_id,
                    account_id=rule.account_id,
                    transfer_account_id=rule.transfer_account_id,
                    category_id=rule.category_id,
                    type=rule.type,
                    amount=rule.amount,
                    description=rule.description,
                    occurred_on=rule.next_date,
                )
            )
            created += 1
            steps += 1
            rule.next_date = advance(rule)
        if rule.end_date is not None and rule.next_date > rule.end_date:
            rule.active = False
    await session.commit()
    return created
