import uuid
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, ConflictError, NotFoundError
from app.models import Budget, BudgetPeriod, CategoryKind, Transaction, TransactionType
from app.schemas.budget import BudgetCreate, BudgetOut, BudgetUpdate
from app.services import categories


def next_month(month: date) -> date:
    return date(month.year + month.month // 12, month.month % 12 + 1, 1)


def period_start(period: BudgetPeriod, day: date) -> date:
    """Primer día del periodo que contiene `day` (las semanas empiezan el lunes)."""
    if period == BudgetPeriod.month:
        return day.replace(day=1)
    if period == BudgetPeriod.week:
        return day - timedelta(days=day.weekday())
    return day


def period_end(period: BudgetPeriod, start: date) -> date:
    """Primer día del periodo siguiente (límite exclusivo)."""
    if period == BudgetPeriod.month:
        return next_month(start)
    if period == BudgetPeriod.week:
        return start + timedelta(days=7)
    return start + timedelta(days=1)


async def _spent_in(
    session: AsyncSession, user_id: uuid.UUID, start: date, end: date
) -> tuple[dict[uuid.UUID | None, Decimal], Decimal]:
    """Gasto del periodo por categoría y el total (una sola consulta)."""
    rows = await session.execute(
        select(Transaction.category_id, func.sum(Transaction.amount))
        .where(
            Transaction.user_id == user_id,
            Transaction.type == TransactionType.expense,
            Transaction.occurred_on >= start,
            Transaction.occurred_on < end,
        )
        .group_by(Transaction.category_id)
    )
    by_category = {cat: Decimal(total or 0) for cat, total in rows}
    return by_category, sum(by_category.values(), Decimal(0))


def _build(budget: Budget, start: date, spent: Decimal) -> BudgetOut:
    period = BudgetPeriod(budget.period)
    return BudgetOut(
        id=budget.id,
        created_at=budget.created_at,
        category_id=budget.category_id,
        period=period,
        month=start,
        start=start,
        end=period_end(period, start) - timedelta(days=1),
        recurring=budget.recurring,
        starts_on=budget.month,
        amount=budget.amount,
        spent=spent,
        remaining=budget.amount - spent,
    )


async def _with_spent(
    session: AsyncSession, user_id: uuid.UUID, items: list[tuple[Budget, date]]
) -> list[BudgetOut]:
    """Calcula el gasto de cada presupuesto en su periodo (una consulta por periodo distinto)."""
    cache: dict[tuple[BudgetPeriod, date], tuple[dict[uuid.UUID | None, Decimal], Decimal]] = {}
    out: list[BudgetOut] = []
    for budget, start in items:
        period = BudgetPeriod(budget.period)
        key = (period, start)
        if key not in cache:
            cache[key] = await _spent_in(session, user_id, start, period_end(period, start))
        by_category, total = cache[key]
        spent = (
            total if budget.category_id is None else by_category.get(budget.category_id, Decimal(0))
        )
        out.append(_build(budget, start, spent))
    return out


async def _get_owned(session: AsyncSession, user_id: uuid.UUID, budget_id: uuid.UUID) -> Budget:
    budget = await session.get(Budget, budget_id)
    if budget is None or budget.user_id != user_id:
        raise NotFoundError("Presupuesto no encontrado")
    return budget


async def effective_budgets(
    session: AsyncSession, user_id: uuid.UUID, period: BudgetPeriod, day: date
) -> list[tuple[Budget, date]]:
    """Presupuestos que rigen el periodo que contiene `day`: los de ese periodo y los recurrentes
    que ya empezaron. Uno puntual sustituye al recurrente de la misma categoría en su periodo."""
    start = period_start(period, day)
    rows = (
        await session.scalars(
            select(Budget)
            .where(
                Budget.user_id == user_id,
                Budget.period == period,
                or_(Budget.month == start, Budget.recurring.is_(True) & (Budget.month <= start)),
            )
            .order_by(Budget.month.desc())
        )
    ).all()
    chosen: dict[uuid.UUID | None, Budget] = {}
    for b in rows:
        current = chosen.get(b.category_id)
        exact = b.month == start and not b.recurring
        if current is None or (exact and not (current.month == start and not current.recurring)):
            chosen[b.category_id] = b
    return [(b, start) for b in chosen.values()]


async def list_budgets(
    session: AsyncSession,
    user_id: uuid.UUID,
    month: date | None = None,
    period: BudgetPeriod | None = None,
    on: date | None = None,
) -> list[BudgetOut]:
    if month is not None and period is None:
        period, on = BudgetPeriod.month, month
    if period is not None:
        items = await effective_budgets(session, user_id, period, on or date.today())
        return await _with_spent(session, user_id, items)
    budgets = (
        await session.scalars(
            select(Budget).where(Budget.user_id == user_id).order_by(Budget.month.desc())
        )
    ).all()
    return await _with_spent(session, user_id, [(b, b.month) for b in budgets])


async def monthly_total(session: AsyncSession, user_id: uuid.UUID, month_start: date) -> Decimal:
    """Lo presupuestado para el mes: el general si lo hay; si no, la suma por categorías."""
    items = await effective_budgets(session, user_id, BudgetPeriod.month, month_start)
    general = [b for b, _ in items if b.category_id is None]
    if general:
        return general[0].amount
    return sum((b.amount for b, _ in items), Decimal(0))


async def _check_category(
    session: AsyncSession, user_id: uuid.UUID, category_id: uuid.UUID
) -> None:
    category = await categories.get_owned(session, user_id, category_id)
    if category.kind != CategoryKind.expense:
        raise AppError("Solo se pueden presupuestar categorías de gasto")


async def _check_unique(
    session: AsyncSession, user_id: uuid.UUID, budget: Budget, ignore: uuid.UUID | None = None
) -> None:
    """Un presupuesto por categoría y periodo, y uno solo que se repita (también el general,
    que la base de datos no puede vigilar porque su categoría es nula)."""
    same = select(Budget.id).where(
        Budget.user_id == user_id,
        Budget.period == budget.period,
        Budget.category_id.is_(None)
        if budget.category_id is None
        else Budget.category_id == budget.category_id,
        Budget.recurring.is_(True) if budget.recurring else Budget.month == budget.month,
    )
    if not budget.recurring:
        same = same.where(Budget.recurring.is_(False))
    if ignore is not None:
        same = same.where(Budget.id != ignore)
    if await session.scalar(same.limit(1)) is not None:
        raise ConflictError(
            "Ya tienes un presupuesto que se repite para eso"
            if budget.recurring
            else "Ya existe un presupuesto para esa categoría en ese periodo"
        )


async def create_budget(session: AsyncSession, user_id: uuid.UUID, data: BudgetCreate) -> BudgetOut:
    if data.category_id is not None:
        await _check_category(session, user_id, data.category_id)
    assert data.start is not None  # lo garantiza el esquema
    start = period_start(data.period, data.start)
    budget = Budget(
        user_id=user_id,
        category_id=data.category_id,
        period=data.period,
        month=start,
        amount=data.amount,
        recurring=data.recurring,
    )
    await _check_unique(session, user_id, budget)
    session.add(budget)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise ConflictError("Ya existe un presupuesto para esa categoría en ese periodo") from exc
    return (await _with_spent(session, user_id, [(budget, start)]))[0]


async def update_budget(
    session: AsyncSession, user_id: uuid.UUID, budget_id: uuid.UUID, data: BudgetUpdate
) -> BudgetOut:
    budget = await _get_owned(session, user_id, budget_id)
    changes = data.model_dump(exclude_unset=True)
    if changes.get("category_id") is not None:
        await _check_category(session, user_id, changes["category_id"])
    for field, value in changes.items():
        if field == "amount" and value is None:
            continue
        setattr(budget, field, value)
    await _check_unique(session, user_id, budget, ignore=budget.id)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise ConflictError("Ya existe un presupuesto para esa categoría en ese periodo") from exc
    start = budget.month
    if budget.recurring:
        start = max(start, period_start(BudgetPeriod(budget.period), date.today()))
    return (await _with_spent(session, user_id, [(budget, start)]))[0]


async def delete_budget(session: AsyncSession, user_id: uuid.UUID, budget_id: uuid.UUID) -> None:
    budget = await _get_owned(session, user_id, budget_id)
    await session.delete(budget)
    await session.commit()
