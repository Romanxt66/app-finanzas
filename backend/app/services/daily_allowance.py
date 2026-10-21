"""«Disponible hoy»: reparte lo que queda del mes entre los días que faltan, dando más peso a los
días de la semana en que el usuario suele gastar más. Todo sale de sus transacciones, presupuestos
y reglas recurrentes; nada se guarda."""

import calendar
import uuid
from collections import defaultdict
from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.models import Account, Budget, RecurringRule, Transaction, TransactionType
from app.schemas.daily_allowance import Basis, DailyAllowance, Status
from app.services.recurring import advance

PATTERN_DAYS = 56  # ocho semanas de historial para medir el patrón semanal
PATTERN_MIN_HISTORY_DAYS = 14  # con menos historial, todos los días pesan igual
PATTERN_MIN_SPEND_DAYS = 8  # y hacen falta varios días con gasto para que el patrón signifique algo
MIN_WEIGHT = Decimal("0.3")
MAX_WEIGHT = Decimal(3)
MAX_RULE_STEPS = 62  # tope de ocurrencias por regla dentro de un mes

CENTS = Decimal("0.01")
ZERO = Decimal(0)


def _cents(value: Decimal) -> Decimal:
    return value.quantize(CENTS, ROUND_HALF_UP)


def weekday_weights(
    expenses: list[tuple[date, Decimal]], today: date
) -> tuple[dict[int, Decimal], bool]:
    """Peso de cada día de la semana (0 = lunes) según el gasto de las últimas semanas.

    Devuelve (pesos, patrón_usado). Sin historial suficiente, todos pesan 1."""
    neutral = {weekday: Decimal(1) for weekday in range(7)}
    window_start = today - timedelta(days=PATTERN_DAYS)
    recent = [(d, a) for d, a in expenses if window_start <= d < today]
    spend_days = {d for d, _ in recent}
    enough = len(spend_days) >= PATTERN_MIN_SPEND_DAYS
    if not enough or (today - min(spend_days)).days < PATTERN_MIN_HISTORY_DAYS:
        return neutral, False
    totals: dict[int, Decimal] = defaultdict(Decimal)
    for d, amount in recent:
        totals[d.weekday()] += amount
    mean = sum(totals.values(), ZERO) / 7
    if mean == 0:
        return neutral, False
    return {
        weekday: min(MAX_WEIGHT, max(MIN_WEIGHT, totals[weekday] / mean)) for weekday in range(7)
    }, True


def compute(
    *,
    today: date,
    currency: str,
    basis: Basis,
    month_total: Decimal,
    spent_before_today: Decimal,
    spent_today: Decimal,
    pending_committed: Decimal,
    weights: dict[int, Decimal],
    pattern_used: bool,
) -> DailyAllowance:
    last_day = calendar.monthrange(today.year, today.month)[1]
    remaining = [today + timedelta(days=i) for i in range(last_day - today.day + 1)]
    pool = month_total - spent_before_today - pending_committed
    weight_sum = sum((weights[d.weekday()] for d in remaining), ZERO)

    if month_total <= 0:
        status, allowance, average = Status.no_data, ZERO, ZERO
    elif pool <= 0:
        status, allowance, average = Status.over, ZERO, ZERO
    else:
        allowance = _cents(pool * weights[today.weekday()] / weight_sum)
        average = _cents(pool / len(remaining))
        status = Status.ok
    left = allowance - spent_today
    if status == Status.ok and left < 0:
        status = Status.tight
    return DailyAllowance(
        day=today,
        currency=currency,
        basis=basis,
        month_total=month_total,
        spent_before_today=spent_before_today,
        spent_today=spent_today,
        pending_committed=pending_committed,
        days_remaining=len(remaining),
        average_per_day=average,
        allowance_today=allowance,
        left_today=left,
        pattern_used=pattern_used,
        status=status,
    )


def _pending_rule_total(rules: list[RecurringRule], month_end: date) -> Decimal:
    """Cobros de reglas activas que aún caen en el mes (los atrasados se registran al abrir)."""
    total = ZERO
    for rule in rules:
        # Copia transitoria: `advance` lee y no debe ensuciar la sesión
        probe = RecurringRule(
            frequency=rule.frequency,
            anchor_day=rule.anchor_day,
            anchor_month=rule.anchor_month,
            next_date=rule.next_date,
        )
        for _ in range(MAX_RULE_STEPS):
            if probe.next_date > month_end or (rule.end_date and probe.next_date > rule.end_date):
                break
            total += rule.amount
            probe.next_date = advance(probe)
    return total


async def _default_currency(session: AsyncSession, user_id: uuid.UUID) -> str:
    currency = await session.scalar(
        select(Account.currency)
        .where(Account.user_id == user_id, Account.archived.is_(False))
        .order_by(Account.created_at, Account.id)
        .limit(1)
    )
    if currency is None:
        raise NotFoundError("Crea una cuenta para calcular tu disponible de hoy")
    return currency


async def daily_allowance(
    session: AsyncSession, user_id: uuid.UUID, today: date, currency: str | None
) -> DailyAllowance:
    currency = currency.upper() if currency else await _default_currency(session, user_id)
    month_start = today.replace(day=1)
    month_end = today.replace(day=calendar.monthrange(today.year, today.month)[1])

    rows = await session.execute(
        select(Transaction.occurred_on, Transaction.type, Transaction.amount)
        .join(Account, Account.id == Transaction.account_id)
        .where(
            Transaction.user_id == user_id,
            Account.currency == currency,
            Transaction.type != TransactionType.transfer,
            Transaction.occurred_on >= min(month_start, today - timedelta(days=PATTERN_DAYS)),
            Transaction.occurred_on <= month_end,
        )
    )
    spent_before = spent_today = future = income = ZERO
    history: list[tuple[date, Decimal]] = []
    for occurred_on, kind, amount in rows:
        if kind == TransactionType.expense:
            history.append((occurred_on, amount))
            if occurred_on > today:
                future += amount
            elif occurred_on == today:
                spent_today += amount
            elif occurred_on >= month_start:
                spent_before += amount
        elif month_start <= occurred_on <= today:
            income += amount

    budget_total = await session.scalar(
        select(func.coalesce(func.sum(Budget.amount), 0)).where(
            Budget.user_id == user_id, Budget.month == month_start
        )
    )
    budget_total = Decimal(budget_total or 0)
    rules = list(
        (
            await session.scalars(
                select(RecurringRule)
                .join(Account, Account.id == RecurringRule.account_id)
                .where(
                    RecurringRule.user_id == user_id,
                    RecurringRule.active.is_(True),
                    RecurringRule.type == TransactionType.expense,
                    Account.currency == currency,
                )
            )
        ).all()
    )
    weights, pattern_used = weekday_weights(history, today)
    basis = Basis.budget if budget_total > 0 else Basis.income
    return compute(
        today=today,
        currency=currency,
        basis=basis,
        month_total=budget_total if basis == Basis.budget else income,
        spent_before_today=spent_before,
        spent_today=spent_today,
        pending_committed=future + _pending_rule_total(rules, month_end),
        weights=weights,
        pattern_used=pattern_used,
    )
