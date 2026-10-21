import uuid
from datetime import date
from typing import Self

from pydantic import BaseModel, Field, model_validator

from app.models.recurring import Frequency
from app.models.transaction import TransactionType
from app.schemas.common import Entity, PositiveMoney


class RecurringCreate(BaseModel):
    type: TransactionType
    account_id: uuid.UUID
    transfer_account_id: uuid.UUID | None = None
    category_id: uuid.UUID | None = None
    amount: PositiveMoney
    description: str = Field(default="", max_length=255)
    frequency: Frequency
    start_date: date
    end_date: date | None = None

    @model_validator(mode="after")
    def _check(self) -> Self:
        if self.type == TransactionType.transfer:
            if self.transfer_account_id is None or self.transfer_account_id == self.account_id:
                raise ValueError(
                    "Una transferencia necesita una cuenta destino distinta de la origen"
                )
            if self.category_id is not None:
                raise ValueError("Una transferencia no lleva categoría")
        elif self.transfer_account_id is not None:
            raise ValueError("transfer_account_id solo aplica a transferencias")
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("La fecha final no puede ser anterior a la inicial")
        return self


class RecurringUpdate(BaseModel):
    amount: PositiveMoney | None = None
    description: str | None = Field(default=None, max_length=255)
    active: bool | None = None
    end_date: date | None = None


class RecurringOut(Entity):
    type: TransactionType
    account_id: uuid.UUID
    transfer_account_id: uuid.UUID | None
    category_id: uuid.UUID | None
    amount: PositiveMoney
    description: str
    frequency: Frequency
    next_date: date
    end_date: date | None
    active: bool


class RunResult(BaseModel):
    created: int
