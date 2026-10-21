import uuid
from datetime import date

from pydantic import BaseModel

from app.schemas.common import Money


class CategoryTotal(BaseModel):
    category_id: uuid.UUID | None
    total: Money


class MonthTotal(BaseModel):
    month: date
    income: Money
    expense: Money


class Summary(BaseModel):
    month: date
    income: Money
    expense: Money
    net: Money
    expense_by_category: list[CategoryTotal]
    trend: list[MonthTotal]
