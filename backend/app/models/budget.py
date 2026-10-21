import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import CheckConstraint, Date, ForeignKey, Numeric, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class Budget(IdMixin, TimestampMixin, Base):
    __tablename__ = "budgets"
    __table_args__ = (
        UniqueConstraint("user_id", "category_id", "month"),
        CheckConstraint("amount > 0", name="ck_budgets_amount_positive"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    category_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("categories.id"))
    month: Mapped[date] = mapped_column(Date)  # siempre el día 1 del mes
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2))
