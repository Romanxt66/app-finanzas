import uuid
from datetime import date

from pydantic import BaseModel, field_validator

from app.schemas.common import Entity, Money, PositiveMoney


class BudgetCreate(BaseModel):
    category_id: uuid.UUID
    month: date
    amount: PositiveMoney

    @field_validator("month")
    @classmethod
    def _first_day(cls, v: date) -> date:
        return v.replace(day=1)


class BudgetUpdate(BaseModel):
    amount: PositiveMoney


class BudgetOut(Entity):
    category_id: uuid.UUID
    month: date
    amount: Money
    spent: Money
    remaining: Money
