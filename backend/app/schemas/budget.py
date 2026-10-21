import uuid
from datetime import date

from pydantic import BaseModel, field_validator, model_validator

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


class BudgetCopy(BaseModel):
    from_month: date
    to_month: date

    @field_validator("from_month", "to_month")
    @classmethod
    def _first_day(cls, v: date) -> date:
        return v.replace(day=1)

    @model_validator(mode="after")
    def _different(self) -> "BudgetCopy":
        if self.from_month == self.to_month:
            raise ValueError("El mes de origen y el de destino deben ser distintos")
        return self


class BudgetCopyResult(BaseModel):
    created: int
    skipped: int
