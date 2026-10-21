"""Imprime el esquema OpenAPI. No toca la BD; las variables son solo para poder importar la app."""

import json
import os

os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite://")
os.environ.setdefault("SECRET_KEY", "openapi-export-only-secret-0123456789")

from app.main import create_app  # noqa: E402

print(json.dumps(create_app().openapi(), indent=2, ensure_ascii=False))
