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


@lru_cache
def get_settings() -> Settings:
    return Settings()
