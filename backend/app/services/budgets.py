import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, ConflictError, NotFoundError
from app.models import Budget, CategoryKind, Transaction, TransactionType
from app.schemas.budget import BudgetCreate, BudgetOut
from app.services import categories


def next_month(month: date) -> date:
    return date(month.year + month.month // 12, month.month % 12 + 1, 1)


async def _spent(session: AsyncSession, user_id: uuid.UUID, budget: Budget) -> Decimal:
    total = await session.scalar(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.user_id == user_id,
            Transaction.type == TransactionType.expense,
            Transaction.category_id == budget.category_id,
            Transaction.occurred_on >= budget.month,
            Transaction.occurred_on < next_month(budget.month),
        )
    )
    return Decimal(total or 0)


async def _out(session: AsyncSession, user_id: uuid.UUID, budget: Budget) -> BudgetOut:
    spent = await _spent(session, user_id, budget)
    return BudgetOut(
        id=budget.id,
        created_at=budget.created_at,
        category_id=budget.category_id,
        month=budget.month,
        amount=budget.amount,
        spent=spent,
        remaining=budget.amount - spent,
    )


async def _get_owned(session: AsyncSession, user_id: uuid.UUID, budget_id: uuid.UUID) -> Budget:
    budget = await session.get(Budget, budget_id)
    if budget is None or budget.user_id != user_id:
        raise NotFoundError("Presupuesto no encontrado")
    return budget


async def list_budgets(
    session: AsyncSession, user_id: uuid.UUID, month: date | None
) -> list[BudgetOut]:
    stmt = select(Budget).where(Budget.user_id == user_id).order_by(Budget.month.desc())
    if month:
        stmt = stmt.where(Budget.month == month.replace(day=1))
    budgets = (await session.scalars(stmt)).all()
    return [await _out(session, user_id, b) for b in budgets]


async def create_budget(session: AsyncSession, user_id: uuid.UUID, data: BudgetCreate) -> BudgetOut:
    category = await categories.get_owned(session, user_id, data.category_id)
    if category.kind != CategoryKind.expense:
        raise AppError("Solo se pueden presupuestar categorías de gasto")
    budget = Budget(user_id=user_id, **data.model_dump())
    session.add(budget)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise ConflictError("Ya existe un presupuesto para esa categoría y mes") from exc
    return await _out(session, user_id, budget)


async def update_budget(
    session: AsyncSession, user_id: uuid.UUID, budget_id: uuid.UUID, amount: Decimal
) -> BudgetOut:
    budget = await _get_owned(session, user_id, budget_id)
    budget.amount = amount
    await session.commit()
    return await _out(session, user_id, budget)


async def delete_budget(session: AsyncSession, user_id: uuid.UUID, budget_id: uuid.UUID) -> None:
    budget = await _get_owned(session, user_id, budget_id)
    await session.delete(budget)
    await session.commit()
