"""Avisos calculados al vuelo (no se guardan): cobros recurrentes próximos, presupuestos casi
agotados o superados y compras de la Sala de espera listas para decidir."""

import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Account,
    Budget,
    Category,
    RecurringRule,
    TransactionType,
    WaitingItem,
    WaitingStatus,
)
from app.schemas.notification import BUDGET_WARNING_RATIO, Notification
from app.services.budgets import _spent_by_budget
from app.services.waiting_room import _aware

_SEVERITY_ORDER = {"danger": 0, "warning": 1, "info": 2}


def _money(amount: Decimal, currency: str) -> str:
    whole = f"{amount:,.0f}" if amount == amount.to_integral() else f"{amount:,.2f}"
    return f"{whole.replace(',', '.')} {currency}"


def _when(days: int) -> str:
    if days <= 0:
        return "hoy"
    if days == 1:
        return "mañana"
    return f"en {days} días"


async def _recurring(
    session: AsyncSession, user_id: uuid.UUID, today: date, horizon: int
) -> list[Notification]:
    rows = await session.execute(
        select(RecurringRule, Account.currency)
        .join(Account, Account.id == RecurringRule.account_id)
        .where(
            RecurringRule.user_id == user_id,
            RecurringRule.active.is_(True),
            RecurringRule.type == TransactionType.expense,
            RecurringRule.next_date <= today + timedelta(days=horizon),
        )
    )
    out: list[Notification] = []
    for rule, currency in rows:
        if rule.end_date and rule.next_date > rule.end_date:
            continue
        days = (rule.next_date - today).days
        name = rule.description or "Un pago recurrente"
        out.append(
            Notification(
                id=f"recurring:{rule.id}:{rule.next_date.isoformat()}",
                kind="recurring_due",
                severity="warning" if days <= 1 else "info",
                title=f"{name} se cobra {_when(days)}",
                body=f"Ten listos {_money(rule.amount, currency)} en la cuenta.",
                link="/recurring",
                date=rule.next_date,
                amount=rule.amount,
                currency=currency,
            )
        )
    return out


async def _budgets(session: AsyncSession, user_id: uuid.UUID, today: date) -> list[Notification]:
    month = today.replace(day=1)
    rows = await session.execute(
        select(Budget, Category.name)
        .join(Category, Category.id == Budget.category_id)
        .where(Budget.user_id == user_id, Budget.month == month)
    )
    pairs = [(budget, name) for budget, name in rows]
    spent = await _spent_by_budget(session, user_id, [b for b, _ in pairs])
    out: list[Notification] = []
    for budget, name in pairs:
        used = spent.get(budget.id, Decimal(0))
        if budget.amount <= 0 or used < budget.amount * BUDGET_WARNING_RATIO:
            continue
        percent = int(used * 100 / budget.amount)
        exceeded = used > budget.amount
        # El id cambia de «aviso» a «superado»: si leíste el primero, el segundo vuelve a salir
        out.append(
            Notification(
                id=f"budget:{budget.id}:{'over' if exceeded else 'near'}",
                kind="budget_exceeded" if exceeded else "budget_warning",
                severity="danger" if exceeded else "warning",
                title=(
                    f"Te pasaste del presupuesto de {name}"
                    if exceeded
                    else f"Vas al {percent} % del presupuesto de {name}"
                ),
                body=(
                    f"Llevas {percent} % de lo previsto este mes."
                    if exceeded
                    else "Aún queda mes: frena un poco los gastos de esta categoría."
                ),
                link="/budgets",
                date=today,
            )
        )
    return out


async def _waiting(session: AsyncSession, user_id: uuid.UUID, now: datetime) -> list[Notification]:
    items = (
        await session.scalars(
            select(WaitingItem).where(
                WaitingItem.user_id == user_id,
                WaitingItem.status == WaitingStatus.waiting,
            )
        )
    ).all()
    out: list[Notification] = []
    for item in items:
        ready_at = _aware(item.ready_at)
        if ready_at > now:
            continue
        out.append(
            Notification(
                id=f"waiting:{item.id}",
                kind="waiting_ready",
                severity="info",
                title=f"Ya puedes decidir: {item.name}",
                body="Pasó el tiempo de espera. ¿Todavía la quieres?",
                link="/waiting",
                date=ready_at.date(),
                amount=item.amount,
                currency=item.currency,
            )
        )
    return out


async def list_notifications(
    session: AsyncSession, user_id: uuid.UUID, today: date, horizon: int = 3
) -> list[Notification]:
    now = datetime.now(UTC)
    items = [
        *await _budgets(session, user_id, today),
        *await _recurring(session, user_id, today, horizon),
        *await _waiting(session, user_id, now),
    ]
    items.sort(key=lambda n: (_SEVERITY_ORDER[n.severity], n.date))
    return items
