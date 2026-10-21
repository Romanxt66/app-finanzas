import uuid
from datetime import datetime
from decimal import Decimal
from typing import Annotated

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, PlainSerializer

from app.core.currencies import SUPPORTED_CURRENCIES

# Siempre 2 decimales en las respuestas, sin depender del motor (SQLite no normaliza, Postgres sí)
_two_decimals = PlainSerializer(lambda v: f"{v:.2f}", return_type=str, when_used="json")
Money = Annotated[Decimal, Field(max_digits=18, decimal_places=2), _two_decimals]
PositiveMoney = Annotated[Decimal, Field(gt=0, max_digits=18, decimal_places=2), _two_decimals]


def _supported_currency(value: str) -> str:
    code = value.upper()
    if code not in SUPPORTED_CURRENCIES:
        raise ValueError("Moneda no admitida")
    return code


Currency = Annotated[
    str,
    Field(min_length=3, max_length=3, pattern=r"^[A-Za-z]{3}$"),
    AfterValidator(_supported_currency),
]


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Entity(ORMModel):
    id: uuid.UUID
    created_at: datetime
