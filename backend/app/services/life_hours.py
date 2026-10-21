import uuid
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.models import Transaction, TransactionType
from app.models.life_hours import LifeHoursProfile
from app.schemas.life_hours import (
    CategoryHours,
    Conversion,
    MonthHours,
    ProfileIn,
    ProfileOut,
)
from app.services.budgets import next_month

WEEKS_PER_YEAR = Decimal(52)
MONTHS_PER_YEAR = Decimal(12)
CENTS = Decimal("0.01")


def hourly_rate(monthly_net_income: Decimal, weekly_hours: Decimal) -> Decimal:
    hours_per_month = weekly_hours * WEEKS_PER_YEAR / MONTHS_PER_YEAR
    return (monthly_net_income / hours_per_month).quantize(CENTS, ROUND_HALF_UP)


def to_hours(amount: Decimal, rate: Decimal) -> Decimal:
    return (amount / rate).quantize(CENTS, ROUND_HALF_UP)


def _out(profile: LifeHoursProfile) -> ProfileOut:
    return ProfileOut(
        monthly_net_income=profile.monthly_net_income,
        weekly_hours=profile.weekly_hours,
        hourly_rate=hourly_rate(profile.monthly_net_income, profile.weekly_hours),
    )


async def _get(session: AsyncSession, user_id: uuid.UUID) -> LifeHoursProfile:
    profile = await session.scalar(
        select(LifeHoursProfile).where(LifeHoursProfile.user_id == user_id)
    )
    if profile is None:
        raise NotFoundError("Configura tu ingreso y horas semanales primero")
    return profile


async def get_profile(session: AsyncSession, user_id: uuid.UUID) -> ProfileOut:
    return _out(await _get(session, user_id))


async def save_profile(session: AsyncSession, user_id: uuid.UUID, data: ProfileIn) -> ProfileOut:
    profile = await session.scalar(
        select(LifeHoursProfile).where(LifeHoursProfile.user_id == user_id)
    )
    if profile is None:
        profile = LifeHoursProfile(user_id=user_id, **data.model_dump())
        session.add(profile)
    else:
        profile.monthly_net_income = data.monthly_net_income
        profile.weekly_hours = data.weekly_hours
    await session.commit()
    return _out(profile)


async def convert(session: AsyncSession, user_id: uuid.UUID, amount: Decimal) -> Conversion:
    profile = _out(await _get(session, user_id))
    return Conversion(
        amount=amount, hours=to_hours(amount, profile.hourly_rate), hourly_rate=profile.hourly_rate
    )


async def month_summary(session: AsyncSession, user_id: uuid.UUID, month: date) -> MonthHours:
    month = month.replace(day=1)
    rate = _out(await _get(session, user_id)).hourly_rate
    rows = await session.execute(
        select(Transaction.category_id, func.sum(Transaction.amount))
        .where(
            Transaction.user_id == user_id,
            Transaction.type == TransactionType.expense,
            Transaction.occurred_on >= month,
            Transaction.occurred_on < next_month(month),
        )
        .group_by(Transaction.category_id)
        .order_by(func.sum(Transaction.amount).desc())
    )
    by_category = [
        CategoryHours(category_id=category_id, total=total, hours=to_hours(total, rate))
        for category_id, total in rows
    ]
    total = sum((c.total for c in by_category), Decimal(0))
    return MonthHours(
        month=month,
        hourly_rate=rate,
        total=total,
        total_hours=to_hours(total, rate),
        by_category=by_category,
    )
