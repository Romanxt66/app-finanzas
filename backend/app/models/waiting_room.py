import enum
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class WaitingStatus(enum.StrEnum):
    waiting = "waiting"
    bought = "bought"
    skipped = "skipped"


class WaitingItem(IdMixin, TimestampMixin, Base):
    """Compra que el usuario deja «en espera» antes de decidir si la hace."""

    __tablename__ = "waiting_items"
    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_waiting_items_amount_positive"),
        CheckConstraint("wait_hours > 0", name="ck_waiting_items_wait_positive"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2))
    currency: Mapped[str] = mapped_column(String(3))
    wait_hours: Mapped[int] = mapped_column(Integer)
    ready_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[WaitingStatus] = mapped_column(String(10), default=WaitingStatus.waiting)
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
