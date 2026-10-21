from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import UnauthorizedError
from app.core.security import decode_token
from app.db.session import get_session
from app.models import User

_bearer = HTTPBearer(auto_error=False)

SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def get_current_user(
    session: SessionDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> User:
    if credentials is None:
        raise UnauthorizedError("Falta el token de autenticación")
    user = await session.get(User, decode_token(credentials.credentials, "access"))
    if user is None:
        raise UnauthorizedError("Usuario no encontrado")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
