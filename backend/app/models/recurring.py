import enum
import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import Boolean, CheckConstraint, Date, ForeignKey, Integer, Numeric, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin
from app.models.transaction import TransactionType


class Frequency(enum.StrEnum):
    weekly = "weekly"
    monthly = "monthly"
    yearly = "yearly"


class RecurringRule(IdMixin, TimestampMixin, Base):
    """Plantilla de un movimiento que se repite.

    Las ocurrencias vencidas se materializan como Transaction (ver services/recurring.py).
    """

    __tablename__ = "recurring_rules"
    __table_args__ = (CheckConstraint("amount > 0", name="ck_recurring_amount_positive"),)

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    type: Mapped[TransactionType] = mapped_column(String(10))
    account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("accounts.id"))
    transfer_account_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("accounts.id"), nullable=True
    )
    category_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("categories.id"), nullable=True
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2))
    description: Mapped[str] = mapped_column(String(255), default="")
    frequency: Mapped[Frequency] = mapped_column(String(10))
    # Día de inicio: ancla para meses cortos (31 ene → 28 feb → 31 mar, sin arrastrar el recorte)
    anchor_day: Mapped[int] = mapped_column(Integer)
    anchor_month: Mapped[int] = mapped_column(Integer)
    next_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
