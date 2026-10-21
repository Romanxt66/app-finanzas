#!/bin/sh
# Aplica las migraciones y arranca la API. Si la migración falla, el contenedor no arranca.
set -eu

alembic upgrade head

exec uvicorn app.main:app \
    --host 0.0.0.0 --port 8000 \
    --proxy-headers --forwarded-allow-ips='*'
