import enum
import uuid
from decimal import Decimal

from sqlalchemy import Boolean, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class AccountType(enum.StrEnum):
    cash = "cash"
    bank = "bank"
    card = "card"
    savings = "savings"


class Account(IdMixin, TimestampMixin, Base):
    __tablename__ = "accounts"

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    type: Mapped[AccountType] = mapped_column(String(20))
    currency: Mapped[str] = mapped_column(String(3))
    initial_balance: Mapped[Decimal] = mapped_column(Numeric(18, 2), default=Decimal("0"))
    archived: Mapped[bool] = mapped_column(Boolean, default=False)
