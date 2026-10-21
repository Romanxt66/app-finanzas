# PLAN.md — App de Finanzas

> Documento de referencia para **ambas sesiones de Claude** (CLI y Desktop). Léelo completo antes de tocar código. Si algo cambia, se actualiza aquí y se hace commit en `main`.

## 1. Objetivo

Aplicación de finanzas personales bien hecha, con calidad de producción:

- **Backend:** FastAPI (Python)
- **Frontend:** React (TypeScript)
- **Base de datos:** la proporcionará el usuario más adelante (ver §6). Hasta entonces, el código debe ser agnóstico al motor.

### Reglas innegociables

1. **Cero datos hardcodeados.** Ni usuarios, categorías, cuentas, montos, URLs, claves ni textos de ejemplo en el código. Todo viene de la BD o de variables de entorno. Datos de prueba solo en fixtures de tests o scripts de seed explícitos, nunca en el código de la app.
2. **Cero secretos en git.** Solo `.env.example` con nombres de variables y sin valores reales.
3. **Dinero = `Decimal` / `NUMERIC`**, nunca `float`.
4. **Estándar senior:** tipado estricto, tests, migraciones versionadas, validación en el borde, manejo de errores consistente, commits pequeños y atómicos.

## 2. Contexto de las dos sesiones y reparto de ramas

Trabajamos en paralelo desde dos sesiones de Claude, cada una con **su propia rama**. Nunca se trabaja directo sobre `main`.

| Sesión | Rama base de trabajo | Notas |
|---|---|---|
| **Claude CLI** (terminal, esta sesión) | `cli/<tarea>` | Tiene el contexto del plan inicial |
| **Claude Desktop** (app de escritorio) | `desktop/<tarea>` | Tiene datos de sesiones anteriores que el usuario necesita incorporar |

- `main`: siempre estable y desplegable. Solo se actualiza vía Pull Request.
- Cada tarea = una rama corta con prefijo `cli/` o `desktop/` (ej. `cli/backend-auth`, `desktop/frontend-dashboard`) → PR a `main`.
- **Cada sesión es dueña de carpetas/archivos distintos** para evitar conflictos de merge. El reparto concreto por tareas se define en la siguiente fase (§9) y se anota en `TASKS.md`.
- Archivos compartidos (`PLAN.md`, `TASKS.md`, `README.md`, `docker-compose.yml`, contratos de API) solo se modifican en PR pequeños y se avisa al usuario.
- Antes de empezar: `git pull --rebase origin main`. Antes de abrir PR: rebase sobre `main` y tests en verde.
- El **contrato de API** (OpenAPI generado por FastAPI) es el punto de sincronización: el frontend consume tipos generados desde `openapi.json`, no tipos escritos a mano.
- Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.

## 3. Repositorio GitHub

- Crear con `gh repo create` (nombre sugerido: `app-finanzas`, **privado** por defecto) bajo la cuenta del usuario.
- `git init`, rama por defecto `main`, primer commit con la estructura base de este plan.
- Proteger `main`: requerir PR y CI en verde (si el plan de GitHub lo permite).
- Incluir `.gitignore` (Python, Node, `.env`, IDE), `README.md`, `.env.example`, `LICENSE` opcional.
- **Quién lo crea:** una sola sesión (la CLI) para no duplicar. Se confirma con el usuario el nombre y la visibilidad antes de ejecutar.

## 4. Estructura del monorepo

```
app-finanzas/
├── PLAN.md
├── TASKS.md                 # reparto de tareas por sesión/rama (fase siguiente)
├── README.md
├── .env.example
├── .github/workflows/       # CI: lint + tests backend y frontend
├── backend/
│   ├── pyproject.toml
│   ├── alembic/             # migraciones
│   ├── app/
│   │   ├── main.py
│   │   ├── core/            # config (pydantic-settings), seguridad, logging
│   │   ├── db/              # engine, sesión, base
│   │   ├── models/          # SQLAlchemy
│   │   ├── schemas/         # Pydantic
│   │   ├── services/        # lógica de negocio y acceso a datos
│   │   └── api/v1/          # routers
│   └── tests/
└── frontend/
    ├── package.json
    ├── src/
    │   ├── api/             # cliente + tipos generados desde OpenAPI
    │   ├── features/        # accounts, transactions, budgets, reports...
    │   ├── components/      # UI reutilizable
    │   ├── hooks/
    │   ├── routes/
    │   └── lib/
    └── tests/
```

## 5. Stack técnico

**Backend**
- Python 3.12+, FastAPI, Uvicorn
- SQLAlchemy 2.x (async) + Alembic
- Pydantic v2 + `pydantic-settings` (config 100 % por variables de entorno)
- Auth: JWT (access + refresh) con hash de contraseñas (argon2/bcrypt)
- Tooling: `uv` o `poetry`, `ruff`, `mypy` (strict), `pytest` + `pytest-asyncio` + `httpx`

**Frontend**
- React 18+ con TypeScript estricto, Vite
- React Router, TanStack Query (estado de servidor), React Hook Form + Zod
- UI: Tailwind CSS + componentes accesibles (shadcn/ui o similar)
- Gráficos: Recharts (o similar)
- Tooling: oxlint, Prettier, Vitest + Testing Library (TypeScript 5.9: `openapi-typescript` aún no soporta TS 6)
- Tipos de API generados con `openapi-typescript`

**DevOps**
- GitHub Actions: lint, type-check y tests en cada PR

## 6. Base de datos (PENDIENTE — la entrega el usuario)

- Aún no se conoce motor ni credenciales. **No asumir ni inventar.**
- Se conecta únicamente vía `DATABASE_URL` en `.env` (nunca en git).
- Todo el acceso a datos pasa por SQLAlchemy + Alembic, de modo que cambiar de motor no rompa el código. Recomendación por defecto si el usuario no tiene preferencia: **PostgreSQL**.
- Si la BD ya tiene esquema existente: primero se hace ingeniería inversa/inspección y se decide si se adopta tal cual (modelos mapeados + migración baseline) o se migra. **No se modifica una BD existente sin confirmación del usuario.**
- Hasta recibirla: los tests usan SQLite en memoria. Al recibir la BD hay que instalar su driver async (p. ej. `asyncpg`) y correr `alembic upgrade head`.

## 7. Alcance funcional (propuesta inicial, a validar con el usuario)

**MVP**
1. Registro / login / sesión (JWT), perfil de usuario
2. Cuentas (efectivo, banco, tarjeta, ahorro) con saldo calculado
3. Categorías (definidas por el usuario, no hardcodeadas)
4. Transacciones: ingresos, gastos, transferencias entre cuentas; filtros, búsqueda, paginación
5. Presupuestos mensuales por categoría con avance
6. Dashboard: balance, gasto por categoría, tendencia mensual, últimas transacciones

**Después del MVP**
- Transacciones recurrentes, metas de ahorro, multi-moneda, import/export CSV, adjuntos, alertas, modo oscuro, i18n.

> Los datos de "sesiones anteriores" que el usuario tiene en Claude Desktop pueden afectar este alcance (modelo de datos, pantallas, reglas). **Primera tarea de Desktop:** resumir esos datos/decisiones en `docs/contexto-previo.md` para reconciliarlos con este plan.

## 8. Estándares de calidad (Definition of Done)

- Tipos estrictos (`mypy --strict`, `tsc --noEmit`) sin errores
- Lint y formato limpios (`ruff`, `eslint`, `prettier`)
- Tests de servicios y endpoints (backend) y de componentes/hook clave (frontend)
- Migración Alembic por cada cambio de esquema, reversible
- Errores de API con formato uniforme; validación de entrada con Pydantic/Zod
- Sin `print`/`console.log` olvidados; logging estructurado
- CORS, rate-limit básico y headers de seguridad configurados por entorno
- Accesibilidad básica (labels, foco, contraste) y responsive
- PR descrito, revisado y con CI en verde antes de mergear

## 9. Fases

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Plan (este documento) | ✅ |
| 1 | División de tareas por sesión/rama → `TASKS.md` | ⏳ pendiente (Desktop añadirá funciones) |
| 2 | Repo GitHub + scaffolding backend/frontend + CI | ✅ |
| 3 | Reconciliar contexto previo de Desktop (`docs/contexto-previo.md`) | |
| 4 | Conectar la BD real del usuario + migración baseline | |
| 5 | Auth y base del modelo de datos | ✅ |
| 6 | Cuentas, categorías, transacciones (API + UI) | ✅ |
| 7 | Presupuestos y dashboard | ✅ (MVP inicial) |
| 8 | Pulido, E2E, documentación, despliegue | |

## 10. Instrucciones para la sesión Desktop

1. Lee este `PLAN.md` y `TASKS.md` (cuando exista).
2. Trabaja **solo** en ramas `desktop/*` y solo en las carpetas que `TASKS.md` te asigne.
3. No hardcodees datos, no subas secretos, no toques `main` directamente.
4. Si necesitas cambiar algo compartido (contrato de API, esquema, este plan), propónlo en un PR pequeño y avisa al usuario.
5. Aporta primero el contexto de sesiones anteriores en `docs/contexto-previo.md`.
6. Ante cualquier duda de alcance o de la BD, pregunta al usuario en lugar de asumir.

## 11. Estado actual

Repo: https://github.com/Romanxt66/app-finanzas (público). MVP inicial construido por la sesión CLI: backend (auth JWT, cuentas, categorías, transacciones, presupuestos, resumen) y frontend (login/registro, resumen, transacciones, cuentas, categorías, presupuestos). La sesión Desktop añadirá funciones sobre esta base.
