from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError, UnauthorizedError
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
