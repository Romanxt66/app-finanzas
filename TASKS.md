# TASKS.md — Reparto de tareas

> Fase 1 de `PLAN.md`. Nombre del producto: **Alvea**.
> Este archivo es compartido: solo se modifica en PR pequeños y se avisa al usuario.

## Contexto

- La sesión **Desktop** desarrolla el núcleo de la app (auth, cuentas, categorías, transacciones, presupuestos, dashboard).
- Esta sesión (**CLI**) añade funciones diferenciadoras como **módulos independientes**, sin editar archivos del núcleo.
- Se aplican todas las reglas de `PLAN.md` §1 y §8 (sin datos hardcodeados, `Decimal`, tipado estricto, tests, migraciones reversibles).

## Funciones de la sesión CLI

| # | Función | Rama | Estado |
|---|---|---|---|
| 1 | **Horas de vida**: cada gasto expresado en horas de trabajo según el ingreso neto por hora del usuario | `cli/life-hours` | pendiente |
| 3 | **Suscripciones fantasma**: detecta cobros recurrentes no marcados, alzas silenciosas de precio, duplicados y pruebas gratuitas que pasan a pago | `cli/ghost-subscriptions` | pendiente |
| 4 | **Presupuesto por ritmo ("disponible hoy")**: cuánto se puede gastar hoy según días restantes, gastos fijos pendientes y patrones de gasto | `cli/daily-allowance` | pendiente |

Una rama y un PR por función, en este orden: 1 → 3 → 4.

## Carpetas propias de la sesión CLI

Ningún otro PR debería tocar estas rutas. Todas son archivos nuevos dentro de la estructura de `PLAN.md` §4.

| Función | Backend | Frontend |
|---|---|---|
| Horas de vida | `backend/app/{models,schemas,repositories,services,api/v1}/life_hours*.py` | `frontend/src/features/life-hours/` |
| Suscripciones fantasma | `backend/app/{models,schemas,repositories,services,api/v1}/ghost_subscriptions*.py` | `frontend/src/features/ghost-subscriptions/` |
| Presupuesto por ritmo | `backend/app/{schemas,services,api/v1}/daily_allowance*.py` | `frontend/src/features/daily-allowance/` |
| Tests | `backend/tests/{life_hours,ghost_subscriptions,daily_allowance}/` | junto a cada feature |

## Dependencias con el núcleo (a acordar con Desktop)

Las funciones **leen** datos del núcleo y no deben modificar sus tablas ni sus servicios.

1. **Transacciones**: fecha, importe (`Decimal`), cuenta, categoría, comercio/descripción y tipo. Necesario para las 3 funciones.
2. **Usuario autenticado**: dependencia de FastAPI para obtener el usuario actual.
3. **Gastos recurrentes / fijos**: la función 4 los necesita. El plan los sitúa después del MVP, así que la función 4 deriva los fijos pendientes de las transacciones históricas hasta que existan.
4. **Migraciones Alembic**: las tablas nuevas (por ejemplo, el ingreso por hora del usuario o las suscripciones detectadas) van en migraciones propias que encadenan sobre la última revisión de `main`. Rebase antes de abrir PR para evitar dos cabezas en Alembic.
5. **Contrato OpenAPI**: los endpoints nuevos cuelgan de prefijos propios (`/api/v1/life-hours`, `/api/v1/ghost-subscriptions`, `/api/v1/daily-allowance`) y el frontend consume los tipos generados.

## Bloqueos actuales

- `main` solo contiene `PLAN.md` y `.gitignore`. Aún no hay scaffolding de backend/frontend (Fase 2), así que la implementación espera a que Desktop lo suba, o se acuerda con el usuario quién lo crea.
- Sin motor de base de datos definido (`PLAN.md` §6): desarrollar contra el contenedor local de docker-compose.

## Preguntas abiertas

- ¿Quién crea el scaffolding de la Fase 2?
- Función 1: ¿el ingreso por hora se introduce a mano o se calcula desde horas semanales + ingreso neto del usuario?
