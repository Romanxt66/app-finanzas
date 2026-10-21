import enum
from datetime import date

from pydantic import BaseModel

from app.schemas.common import Money


class Basis(enum.StrEnum):
    budget = "budget"
    income = "income"


class Status(enum.StrEnum):
    ok = "ok"
    tight = "tight"  # hoy ya se gastó más de lo que tocaba
    over = "over"  # no queda margen para el resto del mes
    no_data = "no_data"  # sin presupuesto ni ingresos este mes: no hay base para calcular


class DailyAllowance(BaseModel):
    day: date
    currency: str
    basis: Basis
    month_total: Money
    spent_before_today: Money
    spent_today: Money
    pending_committed: Money
    days_remaining: int
    average_per_day: Money
    allowance_today: Money
    left_today: Money
    pattern_used: bool
    status: Status
