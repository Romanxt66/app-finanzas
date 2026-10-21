import uuid
from decimal import Decimal

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFoundError
from app.models import Goal, GoalContribution
from app.schemas.goal import ContributionCreate, GoalCreate, GoalOut, GoalUpdate


async def _saved(session: AsyncSession, goal_id: uuid.UUID) -> Decimal:
    total = await session.scalar(
        select(func.coalesce(func.sum(GoalContribution.amount), 0)).where(
            GoalContribution.goal_id == goal_id
        )
    )
    return Decimal(total or 0)


def _out(goal: Goal, saved: Decimal) -> GoalOut:
    return GoalOut(
        id=goal.id,
        created_at=goal.created_at,
        name=goal.name,
        target_amount=goal.target_amount,
        currency=goal.currency,
        deadline=goal.deadline,
        saved=saved,
        remaining=max(goal.target_amount - saved, Decimal(0)),
        achieved=saved >= goal.target_amount,
    )


async def get_owned(session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID) -> Goal:
    goal = await session.get(Goal, goal_id)
    if goal is None or goal.user_id != user_id:
        raise NotFoundError("Meta no encontrada")
    return goal


async def list_goals(session: AsyncSession, user_id: uuid.UUID) -> list[GoalOut]:
    goals = (
        await session.scalars(select(Goal).where(Goal.user_id == user_id).order_by(Goal.created_at))
    ).all()
    # Un único GROUP BY para todas las metas (evita una consulta por meta)
    rows = await session.execute(
        select(GoalContribution.goal_id, func.sum(GoalContribution.amount))
        .where(GoalContribution.user_id == user_id)
        .group_by(GoalContribution.goal_id)
    )
    totals = {goal_id: Decimal(total or 0) for goal_id, total in rows}
    return [_out(g, totals.get(g.id, Decimal(0))) for g in goals]


async def create_goal(session: AsyncSession, user_id: uuid.UUID, data: GoalCreate) -> GoalOut:
    goal = Goal(user_id=user_id, **data.model_dump())
    session.add(goal)
    await session.commit()
    await session.refresh(goal)
    return _out(goal, Decimal(0))


async def update_goal(
    session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID, data: GoalUpdate
) -> GoalOut:
    goal = await get_owned(session, user_id, goal_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(goal, field, value)
    await session.commit()
    return _out(goal, await _saved(session, goal.id))


async def delete_goal(session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID) -> None:
    goal = await get_owned(session, user_id, goal_id)
    await session.execute(delete(GoalContribution).where(GoalContribution.goal_id == goal.id))
    await session.delete(goal)
    await session.commit()


async def list_contributions(
    session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID
) -> list[GoalContribution]:
    await get_owned(session, user_id, goal_id)
    stmt = (
        select(GoalContribution)
        .where(GoalContribution.goal_id == goal_id)
        .order_by(GoalContribution.occurred_on.desc(), GoalContribution.created_at.desc())
    )
    return list((await session.scalars(stmt)).all())


async def add_contribution(
    session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID, data: ContributionCreate
) -> GoalContribution:
    goal = await get_owned(session, user_id, goal_id)
    if data.amount < 0 and await _saved(session, goal.id) + data.amount < 0:
        raise AppError("No puedes retirar más de lo que has ahorrado en esta meta")
    contribution = GoalContribution(goal_id=goal.id, user_id=user_id, **data.model_dump())
    session.add(contribution)
    await session.commit()
    await session.refresh(contribution)
    return contribution


async def delete_contribution(
    session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID, contribution_id: uuid.UUID
) -> None:
    goal = await get_owned(session, user_id, goal_id)
    contribution = await session.get(GoalContribution, contribution_id)
    if contribution is None or contribution.goal_id != goal.id:
        raise NotFoundError("Aporte no encontrado")
    if contribution.amount > 0 and await _saved(session, goal.id) - contribution.amount < 0:
        raise AppError("Eliminar este aporte dejaría la meta con saldo negativo")
    await session.delete(contribution)
    await session.commit()
