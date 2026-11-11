import uuid
from datetime import date
from typing import Self

from pydantic import BaseModel, model_validator

from app.models.budget import BudgetPeriod
from app.schemas.common import Entity, Money, PositiveMoney


class BudgetCreate(BaseModel):
    """`start` es cualquier día del periodo (se lleva a su inicio). `month` se acepta por
    compatibilidad con las apps anteriores (presupuestos mensuales)."""

    category_id: uuid.UUID | None = None
    period: BudgetPeriod = BudgetPeriod.month
    start: date | None = None
    month: date | None = None
    amount: PositiveMoney
    recurring: bool = False

    @model_validator(mode="after")
    def _start(self) -> Self:
        if self.start is None:
            self.start = self.month
        if self.start is None:
            raise ValueError("Indica el día, la semana o el mes del presupuesto")
        return self


class BudgetUpdate(BaseModel):
    amount: PositiveMoney | None = None
    category_id: uuid.UUID | None = None
    recurring: bool | None = None


class BudgetOut(Entity):
    category_id: uuid.UUID | None
    period: BudgetPeriod
    # Inicio del periodo mostrado (en uno recurrente, el periodo consultado); `month` = `start`
    month: date
    start: date
    # Último día del periodo (incluido)
    end: date
    recurring: bool
    # Primer periodo del presupuesto (en los recurrentes, desde cuándo se repite)
    starts_on: date
    amount: Money
    spent: Money
    remaining: Money
