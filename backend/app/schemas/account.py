from pydantic import BaseModel, Field

from app.models.account import AccountType
from app.schemas.common import Currency, Entity, Money


class AccountCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    type: AccountType
    currency: Currency
    initial_balance: Money


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    type: AccountType | None = None
    archived: bool | None = None
    initial_balance: Money | None = None
    # Saldo real de hoy: se ajusta el saldo inicial para que cuadre (sin crear movimientos)
    balance: Money | None = None


class AccountOut(Entity):
    name: str
    type: AccountType
    currency: str
    initial_balance: Money
    archived: bool
    balance: Money
