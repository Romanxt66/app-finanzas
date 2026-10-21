import uuid
from datetime import date
from typing import Self

from pydantic import BaseModel, Field, model_validator

from app.models.transaction import TransactionType
from app.schemas.common import Entity, PositiveMoney


class TransactionCreate(BaseModel):
    type: TransactionType
    account_id: uuid.UUID
    transfer_account_id: uuid.UUID | None = None
    category_id: uuid.UUID | None = None
    amount: PositiveMoney
    description: str = Field(default="", max_length=255)
    occurred_on: date

    @model_validator(mode="after")
    def _check_shape(self) -> Self:
        if self.type == TransactionType.transfer:
            if self.transfer_account_id is None:
                raise ValueError("Una transferencia requiere transfer_account_id")
            if self.transfer_account_id == self.account_id:
                raise ValueError("La cuenta destino debe ser distinta de la origen")
            if self.category_id is not None:
                raise ValueError("Una transferencia no lleva categoría")
        elif self.transfer_account_id is not None:
            raise ValueError("transfer_account_id solo aplica a transferencias")
        return self


class TransactionOut(Entity):
    type: TransactionType
    account_id: uuid.UUID
    transfer_account_id: uuid.UUID | None
    category_id: uuid.UUID | None
    amount: PositiveMoney
    description: str
    occurred_on: date


class TransactionPage(BaseModel):
    items: list[TransactionOut]
    total: int
    limit: int
    offset: int
