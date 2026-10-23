# Alvea 2 — frontend Flutter (web)

Segundo frontend de Alvea, escrito en Flutter, que usa **el mismo backend** FastAPI (`/api/v1`).
No hay cambios en la API: lo que ya consumía la web React lo consume esta app.

Paridad con la web React: mismas pantallas, mismas rutas (`/transactions`, `/budgets`…), mismo diseño y mismas animaciones.

- **Pantallas:** acceso y registro (héroe con tarjetas flotantes), Resumen (saldo, «Disponible hoy», KPIs, tendencia, dona por
  categoría, horas de vida, suscripciones fantasma, recientes), Movimientos (filtros, edición, exportar CSV), Cuentas, Categorías,
  Presupuestos, Metas, Recurrentes, Suscripciones, Importar CSV, Más y Perfil.
- **Diseño "Cristal":** los colores, radios, sombras y desenfoques salen de `design/tokens.json`. `lib/ui/tokens.g.dart` se
  **genera**: `dart run tool/gen_tokens.dart` (el CI falla si está desactualizado). No editarlo a mano.
- **Movimiento:** entrada escalonada de módulos (`cr-rise`), filas que aparecen (`cr-fade`), barras que crecen, cifras que
  cuentan hasta su valor, dona y medidor animados, aurora de fondo a la deriva, menús y diálogos con "pop", avisos (toasts),
  esqueletos con brillo y elevación al pasar el puntero. Todo respeta «reducir movimiento».
- **Iconos:** los mismos trazos SVG de la web (`lib/ui/icons.dart`). **Tipografía:** Manrope y un respaldo de símbolos van
  incluidos en `assets/fonts` (la app no pide nada a CDNs, requisito de la CSP).

## Desarrollo

```bash
cd flutter_app
flutter pub get
# Backend local en :8000 con CORS_ORIGINS=["http://localhost:8081"]
flutter run -d chrome --web-port 8081 --dart-define=API_URL=http://localhost:8000
flutter analyze && flutter test
dart run tool/gen_tokens.dart   # tras cambiar design/tokens.json
```

`API_URL` vacío (producción) = mismo origen: nginx reenvía `/api` al backend, sin CORS.

## Despliegue (Coolify)

`Dockerfile` (Flutter fijado por tag de git + nginx) y `docker-compose.yml` (servicio `alvea2-web`, unido a la red
`coolify` para alcanzar `alvea-api`). Variable opcional: `API_UPSTREAM` (por defecto `http://alvea-api:8000`).
Dominio: https://alvea2.softlane.click (puerto 80 del servicio `alvea2-web`).
La versión de Flutter debe coincidir en `Dockerfile` (`FLUTTER_VERSION`), CI y el entorno local.

Licencias: Manrope (SIL OFL) y un subconjunto de DejaVu Sans para símbolos (licencia libre de Bitstream Vera/DejaVu).
