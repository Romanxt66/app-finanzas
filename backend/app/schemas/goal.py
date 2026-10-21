import uuid
from datetime import date
from decimal import Decimal

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import Currency, Entity, Money, ORMModel, PositiveMoney


class GoalCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    target_amount: PositiveMoney
    currency: Currency
    deadline: date | None = None

    @field_validator("currency")
    @classmethod
    def _upper(cls, v: str) -> str:
        return v.upper()


class GoalUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    target_amount: PositiveMoney | None = None
    deadline: date | None = None


class GoalOut(Entity):
    name: str
    target_amount: Money
    currency: str
    deadline: date | None
    saved: Money
    remaining: Money
    achieved: bool


class ContributionCreate(BaseModel):
    amount: Money
    occurred_on: date
    note: str = Field(default="", max_length=255)

    @field_validator("amount")
    @classmethod
    def _non_zero(cls, v: Decimal) -> Decimal:
        if v == 0:
            raise ValueError("El monto no puede ser cero")
        return v


class ContributionOut(ORMModel):
    id: uuid.UUID
    goal_id: uuid.UUID
    amount: Money
    occurred_on: date
    note: str
