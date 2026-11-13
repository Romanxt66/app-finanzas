from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import totp
from app.core.errors import AppError, ConflictError, UnauthorizedError
from app.core.google import GoogleIdentity
from app.core.security import hash_password, needs_rehash, verify_password
from app.models import (
    Account,
    Budget,
    Category,
    Goal,
    GoalContribution,
    IdempotencyRecord,
    LifeHoursProfile,
    RecurringRule,
    Transaction,
    User,
    WaitingItem,
)
from app.schemas.auth import RegisterIn


async def register(session: AsyncSession, data: RegisterIn) -> User:
    email = data.email.lower()
    if await session.scalar(select(User).where(User.email == email)):
        raise ConflictError("El correo ya está registrado")
    user = User(email=email, hashed_password=hash_password(data.password), full_name=data.full_name)
    session.add(user)
    try:
        await session.commit()
    except IntegrityError as exc:
        # Dos altas simultáneas con el mismo correo: la segunda choca con el índice único
        await session.rollback()
        raise ConflictError("El correo ya está registrado") from exc
    return user


# Hash de relleno: si el correo no existe se verifica contra él igualmente, para que la respuesta
# tarde lo mismo y no se pueda averiguar por tiempos qué correos tienen cuenta
_DUMMY_HASH = hash_password("relleno-para-igualar-tiempos")


async def authenticate(session: AsyncSession, email: str, password: str) -> User:
    user = await session.scalar(select(User).where(User.email == email.lower()))
    if user is None or user.hashed_password is None:
        verify_password(password, _DUMMY_HASH)
        raise UnauthorizedError("Credenciales incorrectas")
    if not verify_password(password, user.hashed_password):
        raise UnauthorizedError("Credenciales incorrectas")
    # Si Argon2 sube sus parámetros, el hash se renueva al entrar (el llamador hace commit)
    if needs_rehash(user.hashed_password):
        user.hashed_password = hash_password(password)
    return user


async def google_user(session: AsyncSession, identity: GoogleIdentity) -> User:
    """Cuenta para una identidad de Google: la ya vinculada, la del mismo correo o una nueva.

    Solo se vincula a una cuenta existente por correo si Google confirma que el correo es suyo; si
    no, alguien podría crear en Google una cuenta con un correo ajeno sin verificar y entrar a la
    de otro.
    """
    user = await session.scalar(select(User).where(User.google_sub == identity.sub))
    if user is not None:
        return user
    if not identity.email_verified:
        raise UnauthorizedError("Verifica tu correo en Google antes de usarlo para entrar")
    user = await session.scalar(select(User).where(User.email == identity.email))
    if user is not None:
        user.google_sub = identity.sub
    else:
        name = (identity.name or identity.email.split("@")[0])[:120]
        user = User(
            email=identity.email, hashed_password=None, full_name=name, google_sub=identity.sub
        )
        session.add(user)
    try:
        await session.flush()
    except IntegrityError as exc:
        # Dos primeros accesos simultáneos con la misma cuenta de Google: el otro ya la creó
        await session.rollback()
        existing = await session.scalar(select(User).where(User.google_sub == identity.sub))
        if existing is None:
            raise ConflictError("No se pudo crear la cuenta; inténtalo de nuevo") from exc
        return existing
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
    # Sin contraseña (cuenta de Google) basta el código de la app de autenticación
    if user.hashed_password is not None and not verify_password(password, user.hashed_password):
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


# Orden de borrado: primero lo que apunta a otras tablas del usuario (las claves foráneas no tienen
# ON DELETE CASCADE), al final las cuentas y el propio usuario.
_OWNED = (
    IdempotencyRecord,
    GoalContribution,
    Transaction,
    Budget,
    RecurringRule,
    WaitingItem,
    Goal,
    LifeHoursProfile,
    Category,
    Account,
)


async def delete_account(
    session: AsyncSession,
    user: User,
    password: str | None,
    google: GoogleIdentity | None = None,
) -> None:
    """Borra al usuario y todos sus datos (derecho de supresión; lo exige Google Play).

    Se confirma con la contraseña o, en las cuentas sin contraseña, volviendo a entrar con Google.
    """
    if user.hashed_password is not None:
        if not password or not verify_password(password, user.hashed_password):
            raise AppError("La contraseña no es correcta")
    elif google is None or google.sub != user.google_sub:
        raise AppError("Confirma con la misma cuenta de Google para eliminarla")
    for model in _OWNED:
        await session.execute(delete(model).where(model.user_id == user.id))
    await session.execute(delete(User).where(User.id == user.id))
    await session.commit()
