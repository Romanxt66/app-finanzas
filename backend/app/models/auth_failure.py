from sqlalchemy import Float, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AuthFailure(Base):
    """Un intento fallido (o una acción limitada) para el límite de intentos.

    Vive en la base de datos y no en memoria para que el límite sea el mismo en todos los procesos
    de la API: con varios workers, cada uno llevaría su propia cuenta y el límite real se
    multiplicaría.
    """

    __tablename__ = "auth_failures"
    __table_args__ = (
        Index("ix_auth_failures_scope_key_at", "scope", "key", "at"),
        Index("ix_auth_failures_at", "at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    # Qué límite es (login, correo, registro…) y a quién se aplica (IP+correo, usuario…)
    scope: Mapped[str] = mapped_column(String(32))
    key: Mapped[str] = mapped_column(String(400))
    # Segundos desde la época (time.time): sin zonas horarias y comparable en SQLite y Postgres
    at: Mapped[float] = mapped_column(Float)
