from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel

from app.schemas.common import Money


class Notification(BaseModel):
    # Estable mientras la situación no cambie: el cliente lo usa para marcar avisos como leídos
    id: str
    kind: Literal["recurring_due", "budget_warning", "budget_exceeded", "waiting_ready"]
    severity: Literal["info", "warning", "danger"]
    title: str
    body: str
    # Ruta de la app a la que lleva el aviso
    link: str
    date: date
    amount: Money | None = None
    currency: str | None = None


class NotificationList(BaseModel):
    items: list[Notification]


BUDGET_WARNING_RATIO = Decimal("0.8")
