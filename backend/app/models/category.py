import enum
import uuid

from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class CategoryKind(enum.StrEnum):
    income = "income"
    expense = "expense"


class Category(IdMixin, TimestampMixin, Base):
    __tablename__ = "categories"
    __table_args__ = (UniqueConstraint("user_id", "name", "kind"),)

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    kind: Mapped[CategoryKind] = mapped_column(String(10))
