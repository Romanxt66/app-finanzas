# App de Finanzas

Aplicación de finanzas personales: **FastAPI** (backend) + **React/TypeScript** (frontend).
Ver [`PLAN.md`](PLAN.md) para el plan, las reglas del proyecto y el flujo de ramas.

## Requisitos

- Python 3.12+ y [uv](https://docs.astral.sh/uv/)
- Node 22+ y npm
- Una base de datos accesible por SQLAlchemy async (p. ej. PostgreSQL con `asyncpg`)

## Backend

```bash
cd backend
cp .env.example .env        # completa DATABASE_URL y SECRET_KEY
uv sync
# instala el driver de tu motor, p. ej.: uv add asyncpg
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

Documentación interactiva en <http://localhost:8000/docs>.

```bash
uv run pytest        # tests (usan SQLite en memoria)
uv run ruff check . && uv run mypy app
```

## Frontend

```bash
cd frontend
cp .env.example .env        # VITE_PROXY_TARGET=http://localhost:8000
npm install
npm run dev
```

Los tipos de la API se generan desde el backend: `npm run gen:api` (ejecutar tras cambiar schemas o endpoints y commitear `src/api/openapi.json` y `schema.d.ts`).

```bash
npm test && npm run typecheck && npm run lint
```

## Notas

- Sin datos hardcodeados: toda la configuración va por variables de entorno (`.env`, ignorado por git).
- Los reportes agregados aún no distinguen monedas (post-MVP: multi-moneda).
