#!/bin/sh
# Aplica las migraciones y arranca la API. Si la migración falla, el contenedor no arranca.
set -eu

alembic upgrade head

# Varios procesos para usar todos los núcleos del servidor (WEB_CONCURRENCY; por defecto 2).
# Es seguro: el límite de intentos y la idempotencia viven en la base de datos, no en memoria,
# y la API no tiene tareas programadas dentro del proceso que se repetirían en cada worker.
exec uvicorn app.main:app \
    --host 0.0.0.0 --port 8000 \
    --workers "${WEB_CONCURRENCY:-2}" \
    --proxy-headers --forwarded-allow-ips='*'
