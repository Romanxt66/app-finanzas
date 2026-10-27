from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field

from app.models.waiting_room import WaitingStatus
from app.schemas.common import Currency, Entity, Money, PositiveMoney


class WaitingCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    amount: PositiveMoney
    currency: Currency
    # Por defecto 72 h; hasta 30 días
    wait_hours: int = Field(default=72, ge=1, le=720)


class Decision(StrEnum):
    bought = "bought"
    skipped = "skipped"


class WaitingDecide(BaseModel):
    decision: Decision


class WaitingOut(Entity):
    name: str
    amount: Money
    currency: str
    wait_hours: int
    ready_at: datetime
    status: WaitingStatus
    decided_at: datetime | None
    ready: bool


class SavedTotal(BaseModel):
    currency: str
    total: Money


class WaitingRoom(BaseModel):
    """Compras en espera y lo que el usuario dejó de gastar al descartarlas."""

    items: list[WaitingOut]
    waiting: int
    ready: int
    skipped: int
    bought: int
    # Suma de lo descartado, por moneda (sin convertir)
    not_spent: list[SavedTotal]
