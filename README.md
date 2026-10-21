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

## Despliegue con Docker / Coolify

- `backend/Dockerfile` (uv + Python 3.12, usuario sin privilegios, aplica migraciones al arrancar) y
  `frontend/Dockerfile` (build de Vite servido por nginx, que reenvía `/api` al backend: mismo origen, sin CORS).
- `docker-compose.yml`: despliegue (Coolify). Requiere las variables `DATABASE_URL` y `SECRET_KEY` en el entorno
  (secretas en Coolify). La BD es externa: ver `backend/.env.example` para el formato de la URL.
- `docker-compose.local.yml`: pruebas locales con su propio Postgres (`.env.local.example`).
- Prueba de humo del despliegue: `cd frontend && E2E_BASE_URL=https://<dominio> npm run e2e:prod` (crea un usuario desechable `e2e-prod-*`).
- La app usa su propio usuario y esquema en Postgres (`search_path` del rol), por lo que sus tablas no se mezclan con las de otras apps.

## Diseño (Cristal)

El diseño vive en `design/tokens.json` (fuente única, compartida con la futura app Android) y los componentes en
`frontend/src/design/`. Tras editar los tokens: `cd frontend && npm run gen:tokens`. Detalles y camino a Android
en [`design/README.md`](design/README.md).

## Tests

| Capa | Comando | Qué cubre |
|---|---|---|
| Backend | `cd backend && uv run pytest --cov=app` | seguridad/JWT, endpoints, reglas de negocio, aislamiento entre usuarios, migraciones vs modelos, restricciones de BD |
| Frontend (unitarios y componentes) | `cd frontend && npm test` (`npm run test:coverage`) | cliente HTTP con refresh de token, formularios, validaciones, páginas con API simulada |
| E2E (navegador real) | `cd frontend && npx playwright install chromium && npm run e2e` | flujo completo con backend real y BD SQLite desechable |

Calidad estática: `npm run typecheck && npm run lint` (frontend) y `uv run ruff check . && uv run mypy app` (backend).

## Notas

- Sin datos hardcodeados: toda la configuración va por variables de entorno (`.env`, ignorado por git).
- Los reportes agregados aún no distinguen monedas (post-MVP: multi-moneda).
