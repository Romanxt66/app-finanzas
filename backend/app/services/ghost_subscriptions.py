"""Detecta cobros recurrentes que el usuario no registró como tales y avisa de alzas, duplicados
y pruebas gratuitas que pasaron a pago. Se calcula al vuelo desde las transacciones: sin tablas."""

import calendar
import re
import statistics
import unicodedata
import uuid
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Account, RecurringRule, Transaction, TransactionType
from app.schemas.ghost_subscriptions import (
    Alert,
    AlertKind,
    Cadence,
    GhostReport,
    MonthlyTotal,
    Subscription,
)

LOOKBACK_DAYS = 800  # alcanza para ver dos cobros anuales
MIN_CHARGES = {Cadence.weekly: 4, Cadence.monthly: 3, Cadence.yearly: 2}
# (mínimo, máximo) de días entre cobros consecutivos
INTERVAL_DAYS = {Cadence.weekly: (6, 8), Cadence.monthly: (26, 35), Cadence.yearly: (350, 380)}
CADENCE_ORDER = (Cadence.weekly, Cadence.monthly, Cadence.yearly)
REGULARITY = Decimal("0.7")  # fracción mínima de intervalos dentro de la banda
MAX_AMOUNT_SPREAD = Decimal(3)  # el cobro mayor no supera 3 veces el menor
GRACE = Decimal("1.5")  # una serie sigue viva hasta 1,5 periodos sin cobrar
PRICE_RISE = Decimal("0.03")  # alza mínima para avisar (3 %)
DUPLICATE_WINDOW_DAYS = 3
DUPLICATE_RECENT_DAYS = 90
TRIAL_RATIO = Decimal("0.25")  # cobro de prueba: hasta un cuarto del cobro real
TRIAL_WINDOW_DAYS = 45
TRIAL_RECENT_DAYS = 120
TRIAL_EARLY_DAYS = 90  # un comercio habitual (súper, café) cobra mucho más que esto
TRIAL_MAX_EARLY_CHARGES = 4
MERCHANT_WORDS = 3

CENTS = Decimal("0.01")


@dataclass(frozen=True)
class Charge:
    description: str
    amount: Decimal
    day: date
    currency: str


def merchant_key(description: str) -> str:
    """«NETFLIX 4521 *MAR» y «Netflix» → «netflix mar»: sin tildes, dígitos ni signos."""
    decomposed = unicodedata.normalize("NFKD", description.lower())
    text = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    words = [w for w in re.sub(r"[^a-z\s]", " ", text).split() if len(w) > 1]
    return " ".join(words[:MERCHANT_WORDS])


def _add_months(day: date, months: int) -> date:
    index = day.year * 12 + day.month - 1 + months
    year, month = divmod(index, 12)
    month += 1
    return date(year, month, min(day.day, calendar.monthrange(year, month)[1]))


def _step(day: date, cadence: Cadence) -> date:
    if cadence == Cadence.weekly:
        return day + timedelta(days=7)
    return _add_months(day, 1 if cadence == Cadence.monthly else 12)


def _period_days(cadence: Cadence) -> int:
    return {Cadence.weekly: 7, Cadence.monthly: 30, Cadence.yearly: 365}[cadence]


def _monthly_cost(amount: Decimal, cadence: Cadence) -> Decimal:
    factor = {
        Cadence.weekly: Decimal(52) / Decimal(12),
        Cadence.monthly: Decimal(1),
        Cadence.yearly: Decimal(1) / Decimal(12),
    }[cadence]
    return (amount * factor).quantize(CENTS, ROUND_HALF_UP)


def _median(values: list[Decimal]) -> Decimal:
    return Decimal(statistics.median(values)).quantize(CENTS, ROUND_HALF_UP)


def _detect_cadence(days: list[date]) -> Cadence | None:
    intervals = [(b - a).days for a, b in zip(days, days[1:], strict=False)]
    if not intervals:
        return None
    for cadence in CADENCE_ORDER:
        low, high = INTERVAL_DAYS[cadence]
        inside = sum(1 for i in intervals if low <= i <= high)
        if len(days) >= MIN_CHARGES[cadence] and Decimal(inside) / len(intervals) >= REGULARITY:
            return cadence
    return None


def _without_duplicates(charges: list[Charge]) -> list[Charge]:
    """Un mismo cobro repetido en pocos días cuenta una vez para medir el ritmo."""
    kept: list[Charge] = []
    for charge in charges:
        if kept and (charge.day - kept[-1].day).days <= DUPLICATE_WINDOW_DAYS:
            continue
        kept.append(charge)
    return kept


def _series(name: str, charges: list[Charge], today: date, tracked: bool) -> Subscription | None:
    unique = _without_duplicates(charges)
    cadence = _detect_cadence([c.day for c in unique])
    if cadence is None:
        return None
    amounts = [c.amount for c in unique]
    if min(amounts) == 0 or max(amounts) / min(amounts) > MAX_AMOUNT_SPREAD:
        return None
    last = unique[-1]
    if (today - last.day).days > _period_days(cadence) * GRACE:
        return None  # ya no se cobra: probablemente cancelada
    typical = _median(amounts)
    return Subscription(
        name=last.description,
        currency=last.currency,
        cadence=cadence,
        typical_amount=typical,
        last_amount=last.amount,
        last_date=last.day,
        next_expected=_step(last.day, cadence),
        occurrences=len(unique),
        monthly_cost=_monthly_cost(typical, cadence),
        tracked=tracked,
    )


def _price_increase(name: str, charges: list[Charge]) -> Alert | None:
    unique = _without_duplicates(charges)
    if len(unique) < 3:
        return None
    last = unique[-1]
    previous = _median([c.amount for c in unique[:-1]])
    if previous == 0 or last.amount <= previous * (1 + PRICE_RISE):
        return None
    return Alert(
        kind=AlertKind.price_increase,
        name=name,
        currency=last.currency,
        date=last.day,
        amount=last.amount,
        previous_amount=previous,
        change_percent=((last.amount - previous) / previous * 100).quantize(CENTS, ROUND_HALF_UP),
    )


def _duplicates(name: str, charges: list[Charge], today: date) -> list[Alert]:
    alerts: list[Alert] = []
    for earlier, later in zip(charges, charges[1:], strict=False):
        close = (later.day - earlier.day).days <= DUPLICATE_WINDOW_DAYS
        recent = (today - later.day).days <= DUPLICATE_RECENT_DAYS
        if close and recent and later.amount == earlier.amount:
            alerts.append(
                Alert(
                    kind=AlertKind.duplicate,
                    name=name,
                    currency=later.currency,
                    date=later.day,
                    amount=later.amount,
                    previous_amount=earlier.amount,
                )
            )
    return alerts


def _trial_converted(name: str, charges: list[Charge], today: date) -> Alert | None:
    """Primer cobro pequeño seguido de uno mayor, en un comercio que casi no se usa."""
    if len(charges) < 2:
        return None
    first, then = charges[0], charges[1]
    early = sum(1 for c in charges if (c.day - first.day).days <= TRIAL_EARLY_DAYS)
    small = first.amount <= then.amount * TRIAL_RATIO
    within = 0 < (then.day - first.day).days <= TRIAL_WINDOW_DAYS
    recent = (today - then.day).days <= TRIAL_RECENT_DAYS
    if not (small and within and recent and early <= TRIAL_MAX_EARLY_CHARGES):
        return None
    return Alert(
        kind=AlertKind.trial_converted,
        name=name,
        currency=then.currency,
        date=then.day,
        amount=then.amount,
        previous_amount=first.amount,
    )


def analyze(charges: list[Charge], tracked_keys: set[str], today: date) -> GhostReport:
    groups: dict[tuple[str, str], list[Charge]] = defaultdict(list)
    for charge in charges:
        key = merchant_key(charge.description)
        if key:
            groups[(key, charge.currency)].append(charge)

    subscriptions: list[Subscription] = []
    alerts: list[Alert] = []
    for (key, _currency), group in groups.items():
        group.sort(key=lambda c: c.day)
        name = group[-1].description
        series = _series(name, group, today, tracked=key in tracked_keys)
        if series:
            subscriptions.append(series)
            if (alert := _price_increase(name, group)) and series.occurrences >= 3:
                alerts.append(alert)
        alerts.extend(_duplicates(name, group, today))
        if trial := _trial_converted(name, group, today):
            alerts.append(trial)

    subscriptions.sort(key=lambda s: (s.tracked, -s.monthly_cost))
    alerts.sort(key=lambda a: a.date, reverse=True)
    totals: dict[str, Decimal] = defaultdict(Decimal)
    for sub in subscriptions:
        if not sub.tracked:
            totals[sub.currency] += sub.monthly_cost
    return GhostReport(
        subscriptions=subscriptions,
        alerts=alerts,
        untracked_monthly=[MonthlyTotal(currency=c, total=t) for c, t in sorted(totals.items())],
    )


async def report(session: AsyncSession, user_id: uuid.UUID, today: date) -> GhostReport:
    since = today - timedelta(days=LOOKBACK_DAYS)
    rows = await session.execute(
        select(
            Transaction.description, Transaction.amount, Transaction.occurred_on, Account.currency
        )
        .join(Account, Account.id == Transaction.account_id)
        .where(
            Transaction.user_id == user_id,
            Transaction.type == TransactionType.expense,
            Transaction.occurred_on >= since,
            Transaction.occurred_on <= today,
        )
    )
    charges = [Charge(d, a, o, c) for d, a, o, c in rows if d.strip()]
    rules = await session.scalars(
        select(RecurringRule.description).where(
            RecurringRule.user_id == user_id,
            RecurringRule.active.is_(True),
            RecurringRule.type == TransactionType.expense,
        )
    )
    return analyze(charges, {merchant_key(r) for r in rules if r.strip()}, today)
