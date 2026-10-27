from sqlalchemy import JSON, Boolean, Integer, String
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

    # Verificación en dos pasos (TOTP). El secreto se guarda al iniciar la configuración y solo
    # se exige al entrar cuando `totp_enabled` es verdadero (tras confirmar un primer código).
    totp_secret: Mapped[str | None] = mapped_column(String(64), nullable=True, default=None)
    totp_enabled: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    # Último paso de tiempo aceptado: un mismo código no sirve dos veces
    totp_last_step: Mapped[int | None] = mapped_column(Integer, nullable=True, default=None)
    # Hashes SHA-256 de los códigos de recuperación aún sin usar
    recovery_codes: Mapped[list[str] | None] = mapped_column(JSON, nullable=True, default=None)
