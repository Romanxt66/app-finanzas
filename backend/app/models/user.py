from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class User(IdMixin, TimestampMixin, Base):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str] = mapped_column(String(120))
    # Se incrementa al cambiar la contraseña o cerrar sesión en todos los dispositivos:
    # los tokens emitidos con una versión anterior dejan de valer.
    token_version: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
