from fastapi import APIRouter, status

from app.api.deps import CurrentUser, SessionDep
from app.core.errors import UnauthorizedError
from app.core.security import create_token, decode_token
from app.models import User
from app.schemas.auth import LoginIn, RefreshIn, RegisterIn, TokenPair, UserOut
from app.services import auth

router = APIRouter(prefix="/auth", tags=["auth"])


def _tokens(user: User) -> TokenPair:
    return TokenPair(
        access_token=create_token(user.id, "access"),
        refresh_token=create_token(user.id, "refresh"),
    )


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def register(data: RegisterIn, session: SessionDep) -> User:
    return await auth.register(session, data)


@router.post("/login", response_model=TokenPair)
async def login(data: LoginIn, session: SessionDep) -> TokenPair:
    return _tokens(await auth.authenticate(session, data.email, data.password))


@router.post("/refresh", response_model=TokenPair)
async def refresh(data: RefreshIn, session: SessionDep) -> TokenPair:
    user = await session.get(User, decode_token(data.refresh_token, "refresh"))
    if user is None:
        raise UnauthorizedError("Usuario no encontrado")
    return _tokens(user)


@router.get("/me", response_model=UserOut)
async def me(user: CurrentUser) -> User:
    return user
