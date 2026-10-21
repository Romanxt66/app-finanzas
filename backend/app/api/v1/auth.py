from fastapi import APIRouter, Request, status

from app.api.deps import CurrentUser, SessionDep
from app.core.errors import AppError, TooManyRequestsError, UnauthorizedError
from app.core.ratelimit import FailureLimiter
from app.core.security import create_token, decode_token, hash_password, verify_password
from app.models import User
from app.schemas.auth import (
    ChangePasswordIn,
    LoginIn,
    ProfileUpdate,
    RefreshIn,
    RegisterIn,
    TokenPair,
    UserOut,
)
from app.services import auth

router = APIRouter(prefix="/auth", tags=["auth"])
# Por IP+correo (5/15 min); respaldo solo por correo si la IP se falsifica (X-Forwarded-For)
login_limiter = FailureLimiter()
email_limiter = FailureLimiter(max_failures=20)


def _tokens(user: User) -> TokenPair:
    return TokenPair(
        access_token=create_token(user.id, "access"),
        refresh_token=create_token(user.id, "refresh"),
    )


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def register(data: RegisterIn, session: SessionDep) -> User:
    return await auth.register(session, data)


@router.post("/login", response_model=TokenPair)
async def login(data: LoginIn, request: Request, session: SessionDep) -> TokenPair:
    email = data.email.lower()
    key = f"{request.client.host if request.client else '?'}|{email}"
    wait = max(login_limiter.retry_after(key), email_limiter.retry_after(email))
    if wait:
        raise TooManyRequestsError(
            f"Demasiados intentos fallidos. Inténtalo de nuevo en {-(-wait // 60)} min"
        )
    try:
        user = await auth.authenticate(session, data.email, data.password)
    except UnauthorizedError:
        login_limiter.record_failure(key)
        email_limiter.record_failure(email)
        raise
    login_limiter.reset(key)
    email_limiter.reset(email)
    return _tokens(user)


@router.post("/refresh", response_model=TokenPair)
async def refresh(data: RefreshIn, session: SessionDep) -> TokenPair:
    user = await session.get(User, decode_token(data.refresh_token, "refresh"))
    if user is None:
        raise UnauthorizedError("Usuario no encontrado")
    return _tokens(user)


@router.get("/me", response_model=UserOut)
async def me(user: CurrentUser) -> User:
    return user


@router.patch("/me", response_model=UserOut)
async def update_profile(data: ProfileUpdate, user: CurrentUser, session: SessionDep) -> User:
    user.full_name = data.full_name
    await session.commit()
    return user


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(data: ChangePasswordIn, user: CurrentUser, session: SessionDep) -> None:
    if not verify_password(data.current_password, user.hashed_password):
        raise AppError("La contraseña actual es incorrecta")
    if data.current_password == data.new_password:
        raise AppError("La contraseña nueva debe ser distinta de la actual")
    user.hashed_password = hash_password(data.new_password)
    await session.commit()
