# TASKS — reparto entre sesiones y estado de funciones

> Complementa `PLAN.md`. Reglas de ramas: `cli/*` (sesión CLI) y `desktop/*` (sesión Desktop); `main` solo por PR con CI en verde.

## Estado actual (hecho en `main`)

| Área | Funciones |
|---|---|
| Autenticación | registro/login JWT (access+refresh), política de contraseña con motivo, límite de intentos (IP+correo), cambio de contraseña y "cerrar sesión en todos los dispositivos" (`token_version`) |
| Finanzas | cuentas (renombrar/archivar/eliminar sin movimientos), categorías, movimientos (ingreso/gasto/transferencia, filtros, paginación, exportar CSV), presupuestos mensuales, metas de ahorro (aportes/retiros), movimientos recurrentes (semanal/mensual/anual) |
| Resumen | saldo total, KPIs con variación mensual, tendencia 6 meses, gasto por categoría, próximos recurrentes |
| UX | diseño Cristal (claro/oscuro/auto), animaciones con `prefers-reduced-motion`, avisos, confirmaciones, esqueletos, navegación móvil + "Más", PWA instalable |
| Calidad | tests backend (pytest + hypothesis, ≥88), frontend (vitest, ≥113), E2E Playwright (flujos, responsive, a11y axe WCAG AA), CI en GitHub Actions |
| Despliegue | Docker + `docker-compose.yml` en Coolify → https://alvea.softlane.click (esquema `alvea`, usuario `rmn_alvea`) |

## Funciones diferenciadoras (rama `claude/optimistic-gates-yi1wgi`, pendiente de PR)

| Función | Backend | Frontend |
|---|---|---|
| **Horas de vida**: cada gasto expresado en horas de trabajo | `/api/v1/life-hours` (perfil, conversión, resumen mensual), migración `0005` | tarjeta en el resumen, diálogo «¿Cuánto vale tu hora?» y «≈ X h de trabajo» junto a cada gasto |
| **Suscripciones fantasma**: cobros recurrentes sin registrar, alzas silenciosas, duplicados y pruebas que pasan a pago | `/api/v1/ghost-subscriptions` (calculado al vuelo, sin tablas) | pantalla `/subscriptions` (desde «Más») y aviso en el resumen |
| **Disponible hoy**: lo que queda del mes repartido entre los días que faltan, con peso por día de la semana | `/api/v1/daily-allowance` (presupuesto o ingresos + reglas recurrentes pendientes) | medidor animado en el resumen |
| **Inflación personal**: cuánto se encareció lo que compras (mismos comercios, ahora frente a hace un año o seis meses) | `/api/v1/personal-inflation` (calculado al vuelo) | Flutter |
| **Sala de espera**: aparcar una compra 72 h y sumar lo que no gastaste | `/api/v1/waiting-room`, tabla `waiting_items` (migración `0006`) | Flutter |
| **Ánimo del gasto**: cómo te sentías al gastar y en qué ánimo gastas más | campo opcional `mood` en gastos (migración `0006`) y `/api/v1/spending-mood` | Flutter |
| Moneda | `/api/v1/currencies`; cuentas y metas solo admiten las monedas de `backend/app/core/currencies.py` | selector `CurrencySelect` en cuentas y metas |
| Tema | tokens `brand` (violeta) en `design/tokens.json`; `mint` pasó a llamarse `brand` | login rediseñado, menú desplegable de cristal (`design/Select.tsx`), aurora de fondo |

Notas: «Mantener sesión iniciada» guarda los tokens en `localStorage` (si no, en `sessionStorage`). Los botones «Huella» y «Passkey» del login están deshabilitados hasta que exista soporte en el backend.

## Pendiente / ideas (candidatas para la sesión Desktop)

- [ ] Importar movimientos desde CSV del banco (vista previa y mapeo de columnas).
- [ ] Reportes por moneda (hoy el resumen asume la moneda de la primera cuenta).
- [ ] Gráfico de dona por categoría y "tasa de ahorro" en el resumen.
- [ ] Onboarding guiado cuando no hay cuentas.
- [ ] App Android (Capacitor sobre la web, o Compose leyendo `design/tokens.json`).
- [ ] Despliegue automático (webhook de GitHub → Coolify) y copias de seguridad externas.
- [ ] Seguridad de la BD: pasar Lab/Prácticas/Polla a usuarios propios, cerrar el 5433, TLS (ver conversación de auditoría).

## Cómo trabajar sin pisarse

- Backend: `backend/app/{models,schemas,services,api/v1}` + migración Alembic por cambio de esquema (`uv run alembic revision --autogenerate`). El test `test_migrations_match_models` falla si falta.
- Frontend: tipos desde OpenAPI (`npm run gen:api`), tokens desde `design/tokens.json` (`npm run gen:tokens`).
- Antes de abrir PR: `uv run pytest && uv run ruff check . && uv run mypy app` y `npm test && npm run typecheck && npm run lint && npm run e2e`.
