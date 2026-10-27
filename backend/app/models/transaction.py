import enum
import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, Numeric, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class TransactionType(enum.StrEnum):
    income = "income"
    expense = "expense"
    transfer = "transfer"


class SpendingMood(enum.StrEnum):
    """Cómo se sentía el usuario al gastar (opcional, solo en gastos)."""

    happy = "happy"
    calm = "calm"
    stressed = "stressed"
    sad = "sad"
    bored = "bored"


class Transaction(IdMixin, TimestampMixin, Base):
    __tablename__ = "transactions"
    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_transactions_amount_positive"),
        Index("ix_transactions_user_date", "user_id", "occurred_on"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("accounts.id"), index=True)
    transfer_account_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("accounts.id"), nullable=True
    )
    category_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("categories.id"), nullable=True, index=True
    )
    type: Mapped[TransactionType] = mapped_column(String(10))
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2))
    description: Mapped[str] = mapped_column(String(255), default="")
    occurred_on: Mapped[date] = mapped_column(Date)
    mood: Mapped[SpendingMood | None] = mapped_column(String(12), nullable=True, default=None)
