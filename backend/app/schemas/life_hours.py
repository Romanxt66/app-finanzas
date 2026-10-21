import uuid
from datetime import date
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, Field

from app.schemas.common import Money, ORMModel, PositiveMoney

Hours = Annotated[Decimal, Field(max_digits=12, decimal_places=2)]
WeeklyHours = Annotated[Decimal, Field(gt=0, le=168, max_digits=5, decimal_places=2)]


class ProfileIn(BaseModel):
    monthly_net_income: PositiveMoney
    weekly_hours: WeeklyHours


class ProfileOut(ORMModel):
    monthly_net_income: Money
    weekly_hours: Decimal
    hourly_rate: Money


class Conversion(BaseModel):
    amount: Money
    hours: Hours
    hourly_rate: Money


class CategoryHours(BaseModel):
    category_id: uuid.UUID | None
    total: Money
    hours: Hours


class MonthHours(BaseModel):
    month: date
    hourly_rate: Money
    total: Money
    total_hours: Hours
    by_category: list[CategoryHours]
