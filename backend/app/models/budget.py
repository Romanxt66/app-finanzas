import enum
import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    ForeignKey,
    Numeric,
    String,
    UniqueConstraint,
    false,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class BudgetPeriod(enum.StrEnum):
    day = "day"
    week = "week"
    month = "month"


class Budget(IdMixin, TimestampMixin, Base):
    """Límite de gasto para un día, una semana o un mes.

    Sin categoría cubre todos los gastos («presupuesto general»). Con `recurring` se repite en cada
    periodo desde `month` (su inicio) sin crear filas nuevas; uno puntual del mismo periodo y
    categoría lo sustituye solo en ese periodo.
    """

    __tablename__ = "budgets"
    __table_args__ = (
        UniqueConstraint("user_id", "category_id", "period", "month", name="uq_budgets_scope"),
        CheckConstraint("amount > 0", name="ck_budgets_amount_positive"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    category_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("categories.id"), nullable=True
    )
    period: Mapped[BudgetPeriod] = mapped_column(
        String(10), default=BudgetPeriod.month, server_default="month"
    )
    # Inicio del periodo: día 1 del mes, lunes de la semana o el propio día
    month: Mapped[date] = mapped_column(Date)
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2))
    recurring: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
