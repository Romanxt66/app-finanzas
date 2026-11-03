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

## Una sola app (React → Flutter)

La app principal es la de Flutter (`flutter_app/`, rama `cli/flutter-app`). Esta versión React queda congelada:
para enviar a todos los usuarios a la de Flutter, define en el recurso de Coolify de esta app la variable
`APP_REDIRECT_URL` con la URL pública de la de Flutter (p. ej. `https://app.midominio.com`, sin barra final) y
vuelve a desplegar. Todas las páginas responden con una redirección 301 conservando la ruta; `/api`, `/healthz` y
`/sw.js` siguen funcionando. Sin la variable, no cambia nada. Si usas Google Search Console, verifica también el
dominio nuevo (la etiqueta ya está en `flutter_app/web/index.html`) y usa *Cambio de dirección*.

## Copias de seguridad

La base de datos es el Postgres compartido de Coolify (`master-db-central`). Si se pierde su volumen, se
pierde todo: activa las copias automáticas.

1. **Recomendado: copias programadas de Coolify.** En Coolify, abre la base de datos → *Backups* → añade una
   programación (p. ej. `0 3 * * *`, cada día a las 3:00) y, si puedes, un destino S3 (Backblaze B2,
   Cloudflare R2, AWS…) para que la copia no viva en el mismo servidor. Prueba a restaurar una copia de vez
   en cuando.
2. **Alternativa manual o con cron:** `DATABASE_URL=… ./ops/backup_db.sh /ruta/copias` crea un volcado
   comprimido con `pg_dump` y borra los de más de 14 días (`KEEP_DAYS`). Restaurar:
   `pg_restore --clean --no-owner -d postgresql://… archivo.dump`.

## Errores en producción (Sentry, opcional)

Define `SENTRY_DSN` en las variables del recurso de Coolify (crea un proyecto gratuito en sentry.io → *Client
Keys (DSN)*). El backend envía sus errores 500 y los que reporta la app (`POST /api/v1/client-errors`), sin
cuerpos, cabeceras, IP, correos ni tokens. Sin la variable, los errores solo quedan en el log del contenedor
(`app.error` y `app.client`).

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
