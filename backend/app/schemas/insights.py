from datetime import date
from decimal import Decimal
from enum import StrEnum

from pydantic import BaseModel

from app.models.transaction import SpendingMood
from app.schemas.common import Money


class Comparison(StrEnum):
    year = "year"  # mismos 90 días de hace un año
    half_year = "half_year"  # los 90 días que acabaron hace seis meses


class InflationItem(BaseModel):
    merchant: str  # descripción más reciente, tal como la escribió el usuario
    category: str | None
    base_price: Money
    current_price: Money
    change_pct: Decimal
    weight_pct: Decimal  # peso en el gasto comparado


class InflationCategory(BaseModel):
    category: str | None
    change_pct: Decimal
    weight_pct: Decimal


class PersonalInflation(BaseModel):
    """Cuánto se encareció lo que el usuario compra de verdad: precio medio por compra en los
    mismos comercios, ahora frente a un periodo anterior, ponderado por lo que gasta en cada uno."""

    currency: str | None
    comparison: Comparison | None
    current_from: date
    current_to: date
    base_from: date | None
    base_to: date | None
    index_pct: Decimal | None
    coverage_pct: Decimal  # parte del gasto actual que se pudo comparar
    matched: int
    items: list[InflationItem]
    categories: list[InflationCategory]


class MoodStat(BaseModel):
    mood: SpendingMood
    count: int
    total: Money
    average: Money
    share_pct: Decimal  # parte del gasto etiquetado


class MoodHighlight(BaseModel):
    mood: SpendingMood
    average: Money
    baseline: Money  # gasto medio por compra en el mismo periodo, con o sin ánimo
    change_pct: Decimal
    top_weekday: int  # ISO: 1 = lunes … 7 = domingo


class SpendingMoodReport(BaseModel):
    currency: str | None
    date_from: date
    date_to: date
    expenses: int
    tagged: int
    by_mood: list[MoodStat]
    highlight: MoodHighlight | None
