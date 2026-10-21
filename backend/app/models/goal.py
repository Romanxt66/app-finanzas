import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import CheckConstraint, Date, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class Goal(IdMixin, TimestampMixin, Base):
    __tablename__ = "goals"
    __table_args__ = (CheckConstraint("target_amount > 0", name="ck_goals_target_positive"),)

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    target_amount: Mapped[Decimal] = mapped_column(Numeric(18, 2))
    currency: Mapped[str] = mapped_column(String(3))
    deadline: Mapped[date | None] = mapped_column(Date, nullable=True)


class GoalContribution(IdMixin, TimestampMixin, Base):
    """Aporte (positivo) o retiro (negativo) de una meta de ahorro."""

    __tablename__ = "goal_contributions"
    __table_args__ = (CheckConstraint("amount <> 0", name="ck_goal_contributions_nonzero"),)

    goal_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("goals.id"), index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2))
    occurred_on: Mapped[date] = mapped_column(Date)
    note: Mapped[str] = mapped_column(String(255), default="")
