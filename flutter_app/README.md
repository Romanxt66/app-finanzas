# Alvea 2 — frontend Flutter (web)

Segundo frontend de Alvea, escrito en Flutter, que usa **el mismo backend** FastAPI (`/api/v1`).
No hay cambios en la API: lo que ya consumía la web React lo consume esta app.

Pantallas: acceso (login/registro), Resumen (saldo, KPIs, tasa de ahorro, dona por categoría, tendencia),
Movimientos (filtros, búsqueda, alta, eliminar deslizando), Cuentas, Presupuestos por mes, Metas de ahorro
(aportes y retiros), Categorías y Perfil (tema claro/oscuro/auto, cerrar sesión en todos los dispositivos).
Diseño "Cristal" (`design/tokens.json`) con la fuente Manrope incluida en `assets/fonts`.

Pendiente respecto a la web React: movimientos recurrentes, importar CSV, exportar CSV y "horas de vida".

## Desarrollo

```bash
cd flutter_app
flutter pub get
# Backend local en :8000 con CORS_ORIGINS=["http://localhost:8081"]
flutter run -d chrome --web-port 8081 --dart-define=API_URL=http://localhost:8000
flutter analyze && flutter test
```

`API_URL` vacío (producción) = mismo origen: nginx reenvía `/api` al backend, sin CORS.

## Despliegue (Coolify)

`Dockerfile` (Flutter fijado por tag de git + nginx) y `docker-compose.yml` (servicio `alvea2-web`, unido a la red
`coolify` para alcanzar `alvea-api`). Variable opcional: `API_UPSTREAM` (por defecto `http://alvea-api:8000`).
Dominio: https://alvea2.softlane.click (puerto 80 del servicio `alvea2-web`).
La versión de Flutter debe coincidir en `Dockerfile` (`FLUTTER_VERSION`), CI y el entorno local.
