"""Inflación personal y ánimo del gasto. Se calculan al vuelo desde las transacciones: sin tablas.

Ambos informes trabajan con la moneda principal del usuario (la de más gasto en el periodo):
los importes de monedas distintas no se mezclan ni se convierten."""

import statistics
import uuid
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Account, Category, SpendingMood, Transaction, TransactionType
from app.schemas.insights import (
    Comparison,
    InflationCategory,
    InflationItem,
    MoodHighlight,
    MoodStat,
    PersonalInflation,
    SpendingMoodReport,
)
from app.services.ghost_subscriptions import merchant_key

WINDOW_DAYS = 90
# Inicio (días atrás) del periodo base para cada comparación
BASE_OFFSETS = ((Comparison.year, 365), (Comparison.half_year, 180))
MIN_MATCHED = 2  # comercios comparables mínimos para dar un índice
RATIO_LIMITS = (Decimal("0.25"), Decimal(4))  # recorta saltos absurdos (p. ej. compras sueltas)
TOP_ITEMS = 8
MOOD_MONTHS_DAYS = 90
MOOD_MIN_COUNT = 3

ONE = Decimal("0.1")
CENTS = Decimal("0.01")


@dataclass(frozen=True)
class Expense:
    description: str
    amount: Decimal
    day: date
    currency: str
    category: str | None
    mood: SpendingMood | None = None


def _pct(value: Decimal) -> Decimal:
    return (value * 100).quantize(ONE, rounding=ROUND_HALF_UP)


def _primary_currency(expenses: list[Expense]) -> str | None:
    totals: dict[str, Decimal] = defaultdict(Decimal)
    for e in expenses:
        totals[e.currency] += e.amount
    return max(totals, key=lambda c: (totals[c], c)) if totals else None


def _median(values: list[Decimal]) -> Decimal:
    return Decimal(statistics.median(values))


def inflation(expenses: list[Expense], today: date) -> PersonalInflation:
    current_from = today - timedelta(days=WINDOW_DAYS - 1)
    current = [e for e in expenses if current_from <= e.day <= today]
    currency = _primary_currency(current)
    current = [e for e in current if e.currency == currency]
    empty = PersonalInflation(
        currency=currency,
        comparison=None,
        current_from=current_from,
        current_to=today,
        base_from=None,
        base_to=None,
        index_pct=None,
        coverage_pct=Decimal(0),
        matched=0,
        items=[],
        categories=[],
    )
    if not current:
        return empty

    by_merchant: dict[str, list[Expense]] = defaultdict(list)
    for e in current:
        if key := merchant_key(e.description):
            by_merchant[key].append(e)
    spent = sum((e.amount for e in current), Decimal(0))

    for comparison, offset in BASE_OFFSETS:
        base_to = today - timedelta(days=offset)
        base_from = base_to - timedelta(days=WINDOW_DAYS - 1)
        base: dict[str, list[Decimal]] = defaultdict(list)
        for e in expenses:
            if e.currency == currency and base_from <= e.day <= base_to:
                if key := merchant_key(e.description):
                    base[key].append(e.amount)
        keys = [k for k in by_merchant if k in base]
        if len(keys) < MIN_MATCHED:
            continue

        rows: list[tuple[Expense, Decimal, Decimal, Decimal, Decimal]] = []
        for key in keys:
            now = by_merchant[key]
            latest = max(now, key=lambda e: e.day)
            base_price = _median(base[key])
            current_price = _median([e.amount for e in now])
            ratio = min(max(current_price / base_price, RATIO_LIMITS[0]), RATIO_LIMITS[1])
            weight = sum((e.amount for e in now), Decimal(0))
            rows.append((latest, base_price, current_price, ratio, weight))

        total_weight = sum((r[4] for r in rows), Decimal(0))
        index = sum((r[3] * r[4] for r in rows), Decimal(0)) / total_weight - 1

        groups: dict[str | None, list[tuple[Decimal, Decimal]]] = defaultdict(list)
        for latest, _, _, ratio, weight in rows:
            groups[latest.category].append((ratio, weight))
        categories = [
            InflationCategory(
                category=name,
                change_pct=_pct(sum((r * w for r, w in g), Decimal(0)) / sum(w for _, w in g) - 1),
                weight_pct=_pct(sum((w for _, w in g), Decimal(0)) / total_weight),
            )
            for name, g in groups.items()
        ]
        categories.sort(key=lambda c: (-c.change_pct, c.category or ""))

        items = [
            InflationItem(
                merchant=latest.description.strip(),
                category=latest.category,
                base_price=base_price.quantize(CENTS, rounding=ROUND_HALF_UP),
                current_price=current_price.quantize(CENTS, rounding=ROUND_HALF_UP),
                change_pct=_pct(ratio - 1),
                weight_pct=_pct(weight / total_weight),
            )
            for latest, base_price, current_price, ratio, weight in rows
        ]
        # Lo que más pesa en el bolsillo: cambio por peso
        items.sort(key=lambda i: (-abs(i.change_pct * i.weight_pct), i.merchant))
        return empty.model_copy(
            update={
                "comparison": comparison,
                "base_from": base_from,
                "base_to": base_to,
                "index_pct": _pct(index),
                "coverage_pct": _pct(total_weight / spent),
                "matched": len(rows),
                "items": items[:TOP_ITEMS],
                "categories": categories,
            }
        )
    return empty


def moods(expenses: list[Expense], today: date) -> SpendingMoodReport:
    date_from = today - timedelta(days=MOOD_MONTHS_DAYS - 1)
    window = [e for e in expenses if date_from <= e.day <= today]
    currency = _primary_currency([e for e in window if e.mood]) or _primary_currency(window)
    window = [e for e in window if e.currency == currency]
    tagged = [e for e in window if e.mood]
    report = SpendingMoodReport(
        currency=currency,
        date_from=date_from,
        date_to=today,
        expenses=len(window),
        tagged=len(tagged),
        by_mood=[],
        highlight=None,
    )
    if not tagged:
        return report

    groups: dict[SpendingMood, list[Expense]] = defaultdict(list)
    for e in tagged:
        assert e.mood is not None
        groups[e.mood].append(e)
    tagged_total = sum((e.amount for e in tagged), Decimal(0))
    stats = [
        MoodStat(
            mood=mood,
            count=len(g),
            total=sum((e.amount for e in g), Decimal(0)),
            average=(sum((e.amount for e in g), Decimal(0)) / len(g)).quantize(
                CENTS, rounding=ROUND_HALF_UP
            ),
            share_pct=_pct(sum((e.amount for e in g), Decimal(0)) / tagged_total),
        )
        for mood, g in groups.items()
    ]
    stats.sort(key=lambda s: (-s.total, s.mood.value))

    baseline = sum((e.amount for e in window), Decimal(0)) / len(window)
    candidates = [s for s in stats if s.count >= MOOD_MIN_COUNT]
    highlight = None
    if candidates and baseline > 0:
        best = max(candidates, key=lambda s: (s.average / baseline, s.mood.value))
        weekdays = Counter(e.day.isoweekday() for e in groups[best.mood])
        top_weekday = min(weekdays, key=lambda d: (-weekdays[d], d))
        highlight = MoodHighlight(
            mood=best.mood,
            average=best.average,
            baseline=baseline.quantize(CENTS, rounding=ROUND_HALF_UP),
            change_pct=_pct(best.average / baseline - 1),
            top_weekday=top_weekday,
        )
    return report.model_copy(update={"by_mood": stats, "highlight": highlight})


async def _expenses(
    session: AsyncSession, user_id: uuid.UUID, since: date, today: date
) -> list[Expense]:
    rows = await session.execute(
        select(
            Transaction.description,
            Transaction.amount,
            Transaction.occurred_on,
            Account.currency,
            Category.name,
            Transaction.mood,
        )
        .join(Account, Account.id == Transaction.account_id)
        .outerjoin(Category, Category.id == Transaction.category_id)
        .where(
            Transaction.user_id == user_id,
            Transaction.type == TransactionType.expense,
            Transaction.occurred_on >= since,
            Transaction.occurred_on <= today,
        )
    )
    return [Expense(d, a, o, c, n, SpendingMood(m) if m else None) for d, a, o, c, n, m in rows]


async def personal_inflation(
    session: AsyncSession, user_id: uuid.UUID, today: date
) -> PersonalInflation:
    since = today - timedelta(days=BASE_OFFSETS[0][1] + WINDOW_DAYS)
    return inflation(await _expenses(session, user_id, since, today), today)


async def spending_mood(
    session: AsyncSession, user_id: uuid.UUID, today: date
) -> SpendingMoodReport:
    since = today - timedelta(days=MOOD_MONTHS_DAYS)
    return moods(await _expenses(session, user_id, since, today), today)
