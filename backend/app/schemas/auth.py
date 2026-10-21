import uuid

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.common import ORMModel

PASSWORD_MIN = 8
PASSWORD_MAX = 128


def check_password_policy(password: str) -> str:
    """Devuelve la contraseña o lanza un ValueError cuyo mensaje explica qué falta."""
    if len(password) < PASSWORD_MIN:
        raise ValueError(f"La contraseña debe tener al menos {PASSWORD_MIN} caracteres")
    if len(password) > PASSWORD_MAX:
        raise ValueError(f"La contraseña no puede superar {PASSWORD_MAX} caracteres")
    if not any(c.isalpha() for c in password):
        raise ValueError("La contraseña debe incluir al menos una letra")
    if not any(c.isdigit() for c in password):
        raise ValueError("La contraseña debe incluir al menos un número")
    return password


class RegisterIn(BaseModel):
    email: EmailStr
    password: str
    full_name: str = Field(min_length=1, max_length=120)

    @field_validator("password")
    @classmethod
    def _password_policy(cls, v: str) -> str:
        return check_password_policy(v)


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserOut(ORMModel):
    id: uuid.UUID
    email: EmailStr
    full_name: str
