import uuid
from decimal import Decimal

from sqlalchemy import CheckConstraint, ForeignKey, Numeric
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class LifeHoursProfile(IdMixin, TimestampMixin, Base):
    __tablename__ = "life_hours_profiles"
    __table_args__ = (
        CheckConstraint("monthly_net_income > 0", name="ck_life_hours_income_positive"),
        CheckConstraint(
            "weekly_hours > 0 AND weekly_hours <= 168", name="ck_life_hours_weekly_hours_range"
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), unique=True)
    monthly_net_income: Mapped[Decimal] = mapped_column(Numeric(18, 2))
    weekly_hours: Mapped[Decimal] = mapped_column(Numeric(5, 2))
