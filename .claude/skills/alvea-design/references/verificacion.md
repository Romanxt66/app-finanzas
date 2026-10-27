# Verificar un cambio de diseño

Todo desde `flutter_app/` con el SDK de Flutter de la versión fijada en el `Dockerfile`
(`FLUTTER_VERSION`).

## 1. Comprobaciones rápidas

```bash
flutter pub get
dart format lib/ruta/archivo_tocado.dart   # solo lo que cambiaste (page_width 140)
flutter analyze                            # sin incidencias
flutter test                               # todo en verde
dart run tool/gen_tokens.dart && git diff --exit-code lib/ui/tokens.g.dart   # si tocaste tokens
```

Prueba la lógica que añadas (cálculos, textos, reglas de reconocimiento) y, para fallos visuales,
una prueba de regresión que falle sin el arreglo (ver `test/cards_test.dart` y `test/design_test.dart`).

## 2. Ver la app de verdad

1. Backend local (desde `backend/` de la rama `main`, que es el que se despliega):
   ```bash
   DATABASE_URL=sqlite+aiosqlite:///./local.db SECRET_KEY=<32+ caracteres> uv run alembic upgrade head
   DATABASE_URL=sqlite+aiosqlite:///./local.db SECRET_KEY=<lo mismo> \
     CORS_ORIGINS='["http://localhost:8090"]' uv run uvicorn app.main:app --port 8101
   ```
   Crea un usuario y datos de prueba con la API (`/api/v1/auth/register`, `/accounts`,
   `/transactions`…). No uses datos ni credenciales reales.
2. Build web contra ese backend y sírvela como SPA:
   ```bash
   flutter build web --release --no-web-resources-cdn --dart-define=API_URL=http://localhost:8101 -o /tmp/alvea-web
   ```
   (Cualquier servidor estático que devuelva `index.html` para rutas desconocidas sirve.)
3. Capturas con `scripts/capturas.mjs` (Playwright): escritorio 1366×860 y móvil 390×844, arriba
   y desplazado (los módulos de abajo aparecen al desplazar y el cristal debe seguir alineado).
   ```bash
   APP_URL=http://localhost:8090 API_URL=http://localhost:8101 ALVEA_EMAIL=… ALVEA_PASSWORD=… \
     OUT=/tmp/capturas node .claude/skills/alvea-design/scripts/capturas.mjs /,/:700,/accounts,/transactions
   ```
   Necesita Playwright con Chromium: global o el del proyecto web (`NODE_PATH=frontend/node_modules`).
   El script fija el idioma `es-CO`; sin él, Chromium sin interfaz usa la configuración regional
   «C» y la app falla al arrancar.

## 3. Qué mirar en las capturas

- Ninguna tarjeta opaca ni gris: todas dejan ver la luz del fondo.
- Sin franjas ni cortes dentro de las tarjetas al desplazar.
- Titulares con acento en serif; etiquetas mono en minúsculas; cifras grandes legibles.
- Textos largos sin cortarse a media palabra; móvil sin desbordes.
- Curvas de gráficos sin rebotes bajo cero.
- Modo claro: contraste suficiente (botón de sol/luna en la barra superior).
