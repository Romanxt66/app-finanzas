import enum
from datetime import date

from pydantic import BaseModel

from app.schemas.common import Money


class Cadence(enum.StrEnum):
    weekly = "weekly"
    monthly = "monthly"
    yearly = "yearly"


class AlertKind(enum.StrEnum):
    price_increase = "price_increase"
    duplicate = "duplicate"
    trial_converted = "trial_converted"


class Subscription(BaseModel):
    name: str
    currency: str
    cadence: Cadence
    typical_amount: Money
    last_amount: Money
    last_date: date
    next_expected: date
    occurrences: int
    monthly_cost: Money
    # True si ya existe una regla recurrente activa para este cobro; si no, es un cobro «fantasma»
    tracked: bool


class Alert(BaseModel):
    kind: AlertKind
    name: str
    currency: str
    date: date
    amount: Money
    previous_amount: Money | None = None
    change_percent: Money | None = None


class MonthlyTotal(BaseModel):
    currency: str
    total: Money


class GhostReport(BaseModel):
    subscriptions: list[Subscription]
    alerts: list[Alert]
    untracked_monthly: list[MonthlyTotal]
