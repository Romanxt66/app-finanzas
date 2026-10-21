from pydantic import BaseModel, Field, field_validator

from app.models.account import AccountType
from app.schemas.common import Currency, Entity, Money


class AccountCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    type: AccountType
    currency: Currency
    initial_balance: Money

    @field_validator("currency")
    @classmethod
    def _upper(cls, v: str) -> str:
        return v.upper()


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    type: AccountType | None = None
    archived: bool | None = None


class AccountOut(Entity):
    name: str
    type: AccountType
    currency: str
    initial_balance: Money
    archived: bool
    balance: Money
