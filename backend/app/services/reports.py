import uuid
from collections import defaultdict
from datetime import date
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models import Account, Transaction, TransactionType
from app.schemas.report import CategoryTotal, MonthTotal, Summary
from app.services.budgets import next_month

TREND_MONTHS = 6


def _months_back(month: date, count: int) -> date:
    index = month.year * 12 + month.month - 1 - (count - 1)
    return date(index // 12, index % 12 + 1, 1)


async def _currencies(session: AsyncSession, user_id: uuid.UUID) -> list[str]:
    """Monedas de las cuentas del usuario, en el orden en que aparecieron por primera vez."""
    rows = await session.scalars(
        select(Account.currency).where(Account.user_id == user_id).order_by(Account.created_at)
    )
    return list(dict.fromkeys(rows))


async def summary(
    session: AsyncSession, user_id: uuid.UUID, month: date, currency: str | None = None
) -> Summary:
    month = month.replace(day=1)
    currencies = await _currencies(session, user_id)
    if currency is not None:
        currency = currency.upper()
        if currency not in currencies:
            raise AppError("No tienes cuentas en esa moneda")
    elif currencies:
        currency = currencies[0]
    start, end = _months_back(month, TREND_MONTHS), next_month(month)

    rows = await session.execute(
        select(Transaction.occurred_on, Transaction.type, Transaction.amount)
        .join(Account, Account.id == Transaction.account_id)
        .where(
            Transaction.user_id == user_id,
            Account.currency == currency,
            Transaction.type != TransactionType.transfer,
            Transaction.occurred_on >= start,
            Transaction.occurred_on < end,
        )
    )
    per_month: dict[date, dict[str, Decimal]] = defaultdict(
        lambda: {"income": Decimal(0), "expense": Decimal(0)}
    )
    for occurred_on, ttype, amount in rows:
        per_month[occurred_on.replace(day=1)][ttype] += amount

    by_category = await session.execute(
        select(Transaction.category_id, func.sum(Transaction.amount))
        .join(Account, Account.id == Transaction.account_id)
        .where(
            Transaction.user_id == user_id,
            Account.currency == currency,
            Transaction.type == TransactionType.expense,
            Transaction.occurred_on >= month,
            Transaction.occurred_on < end,
        )
        .group_by(Transaction.category_id)
        .order_by(func.sum(Transaction.amount).desc())
    )

    trend: list[MonthTotal] = []
    cursor = start
    while cursor < end:
        totals = per_month.get(cursor, {"income": Decimal(0), "expense": Decimal(0)})
        trend.append(MonthTotal(month=cursor, **totals))
        cursor = next_month(cursor)

    current = per_month.get(month, {"income": Decimal(0), "expense": Decimal(0)})
    return Summary(
        month=month,
        currency=currency,
        currencies=currencies,
        income=current["income"],
        expense=current["expense"],
        net=current["income"] - current["expense"],
        expense_by_category=[CategoryTotal(category_id=c, total=t) for c, t in by_category],
        trend=trend,
    )
