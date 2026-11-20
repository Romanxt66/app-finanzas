from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Toda la configuración viene del entorno (.env). Sin valores por defecto sensibles."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str
    secret_key: str = Field(min_length=32)
    access_token_minutes: int = 15
    refresh_token_days: int = 7
    cors_origins: list[str] = []
    environment: str = "development"
    # Opcional: si se define, los errores del servidor y los que reporta la app se envían a Sentry
    sentry_dsn: str | None = None
    # IDs de cliente de OAuth de Google (web y Android) que pueden iniciar sesión.
    # Vacío = desactivado.
    google_client_ids: list[str] = []
    # Conexiones a la base de datos por proceso de la API (cada worker tiene su propio pool):
    # workers × (pool + desborde) debe quedar por debajo de max_connections de Postgres (100).
    db_pool_size: int = Field(default=5, ge=1)
    db_max_overflow: int = Field(default=10, ge=0)


@lru_cache
def get_settings() -> Settings:
    return Settings()
