import uuid

from pydantic import AliasChoices, BaseModel, EmailStr, Field, field_validator

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


# Las contraseñas que llegan para comprobarse se acotan (pasan por Argon2); la política de las
# nuevas ya limita a PASSWORD_MAX: aquí hay margen por si alguna antigua fuera más larga
_CHECKED_PASSWORD_MAX = 256


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(max_length=_CHECKED_PASSWORD_MAX)
    # Código de la app de autenticación (o de recuperación) si la cuenta tiene 2 pasos activos
    otp: str | None = Field(default=None, max_length=32)


class GoogleLoginIn(BaseModel):
    id_token: str = Field(min_length=20, max_length=4096)
    otp: str | None = Field(default=None, max_length=32)


class RefreshIn(BaseModel):
    refresh_token: str = Field(max_length=2048)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserOut(ORMModel):
    id: uuid.UUID
    email: EmailStr
    full_name: str
    two_factor_enabled: bool = Field(
        default=False, validation_alias=AliasChoices("totp_enabled", "two_factor_enabled")
    )
    # False en cuentas de Google sin contraseña aún (Perfil ofrece crear una)
    email_login: bool = True
    google_linked: bool = False


class ProfileUpdate(BaseModel):
    full_name: str = Field(min_length=1, max_length=120)


class DeleteAccountIn(BaseModel):
    # Con contraseña si la cuenta la tiene; si solo entra con Google, un ID token reciente suyo
    password: str | None = Field(default=None, max_length=_CHECKED_PASSWORD_MAX)
    google_id_token: str | None = Field(default=None, max_length=4096)


class ChangePasswordIn(BaseModel):
    # Vacío solo si la cuenta (creada con Google) aún no tiene contraseña: así se crea la primera
    current_password: str = Field(default="", max_length=_CHECKED_PASSWORD_MAX)
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _password_policy(cls, v: str) -> str:
        return check_password_policy(v)


class TwoFactorSetup(BaseModel):
    secret: str
    otpauth_uri: str


class TwoFactorCode(BaseModel):
    code: str = Field(min_length=6, max_length=32)


class TwoFactorDisable(BaseModel):
    password: str = Field(default="", max_length=_CHECKED_PASSWORD_MAX)  # vacío: cuenta de Google
    code: str = Field(min_length=6, max_length=32)


class RecoveryCodes(BaseModel):
    recovery_codes: list[str]
