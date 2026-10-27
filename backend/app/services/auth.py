from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import totp
from app.core.errors import AppError, ConflictError, UnauthorizedError
from app.core.security import hash_password, verify_password
from app.models import User
from app.schemas.auth import RegisterIn


async def register(session: AsyncSession, data: RegisterIn) -> User:
    email = data.email.lower()
    if await session.scalar(select(User).where(User.email == email)):
        raise ConflictError("El correo ya está registrado")
    user = User(email=email, hashed_password=hash_password(data.password), full_name=data.full_name)
    session.add(user)
    await session.commit()
    return user


async def authenticate(session: AsyncSession, email: str, password: str) -> User:
    user = await session.scalar(select(User).where(User.email == email.lower()))
    if user is None or not verify_password(password, user.hashed_password):
        raise UnauthorizedError("Credenciales incorrectas")
    return user


def check_second_factor(user: User, code: str) -> bool:
    """Valida un código TOTP o de recuperación y lo consume. El llamador hace commit."""
    if not user.totp_enabled or not user.totp_secret:
        return False
    step = totp.matching_step(user.totp_secret, code)
    if step is not None:
        if user.totp_last_step is not None and step <= user.totp_last_step:
            return False  # el mismo código (o uno anterior) ya se usó
        user.totp_last_step = step
        return True
    digest = totp.hash_recovery(code)
    remaining = list(user.recovery_codes or [])
    if len(totp.normalize_recovery(code)) == 10 and digest in remaining:
        remaining.remove(digest)
        user.recovery_codes = remaining
        return True
    return False


def start_two_factor(user: User) -> str:
    """Genera un secreto nuevo, pendiente de confirmar con un primer código."""
    if user.totp_enabled:
        raise ConflictError("La verificación en dos pasos ya está activada")
    user.totp_secret = totp.generate_secret()
    user.totp_last_step = None
    return user.totp_secret


def confirm_two_factor(user: User, code: str) -> list[str]:
    """Activa los dos pasos si el código es válido; devuelve los códigos de recuperación."""
    if user.totp_enabled:
        raise ConflictError("La verificación en dos pasos ya está activada")
    if not user.totp_secret:
        raise AppError("Primero genera el código QR")
    step = totp.matching_step(user.totp_secret, code)
    if step is None:
        raise AppError("El código no es correcto. Revisa la hora del móvil e inténtalo otra vez")
    codes = totp.generate_recovery_codes()
    user.totp_enabled = True
    user.totp_last_step = step
    user.recovery_codes = [totp.hash_recovery(c) for c in codes]
    return codes


def disable_two_factor(user: User, password: str, code: str) -> None:
    if not user.totp_enabled:
        raise AppError("La verificación en dos pasos no está activada")
    if not verify_password(password, user.hashed_password):
        raise AppError("La contraseña es incorrecta")
    if not check_second_factor(user, code):
        raise AppError("El código no es correcto")
    user.totp_enabled = False
    user.totp_secret = None
    user.totp_last_step = None
    user.recovery_codes = None


def regenerate_recovery_codes(user: User, code: str) -> list[str]:
    if not user.totp_enabled:
        raise AppError("La verificación en dos pasos no está activada")
    if not check_second_factor(user, code):
        raise AppError("El código no es correcto")
    codes = totp.generate_recovery_codes()
    user.recovery_codes = [totp.hash_recovery(c) for c in codes]
    return codes
