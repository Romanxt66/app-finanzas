# Alvea 2 — frontend Flutter (web)

Segundo frontend de Alvea, escrito en Flutter, que usa **el mismo backend** FastAPI (`/api/v1`).
No hay cambios en la API: lo que ya consumía la web React lo consume esta app.

Paridad con la web React: mismas pantallas, mismas rutas (`/transactions`, `/budgets`…), mismo diseño y mismas animaciones.

- **Pantallas:** acceso y registro (héroe con tarjetas flotantes), Resumen (saldo, «Disponible hoy», KPIs, tendencia, dona por
  categoría, horas de vida, suscripciones fantasma, recientes), Movimientos (filtros, edición, exportar CSV), Cuentas, Categorías,
  Presupuestos, Metas, Recurrentes, Suscripciones, Importar CSV, Más y Perfil.
- **Funciones propias:** «Alvi», carita animada del resumen que refleja la salud del mes (ahorro, ritmo diario, presupuestos y
  saldo; `financeMood` en `lib/screens/insights.dart`); **inflación personal** (`/personal-inflation`); **ánimo del gasto**
  (selector de caritas al registrar un gasto y resumen `/spending-mood`); y **Sala de espera** (`/waiting`, `/waiting-room`):
  aparcar una compra 1–7 días y sumar lo que no gastaste, con opción de mandarlo a una meta. Las caritas se dibujan en
  vectorial (`lib/ui/mood_face.dart`): sin emojis ni fuentes externas.
- **Diseño "Cristal":** los colores, radios, sombras y desenfoques salen de `design/tokens.json`. `lib/ui/tokens.g.dart` se
  **genera**: `dart run tool/gen_tokens.dart` (el CI falla si está desactualizado). No editarlo a mano.
- **Movimiento:** entrada escalonada de módulos (`cr-rise`) que, si empiezan fuera de pantalla, aparecen al desplazar hasta
  ellos; titular con paralaje al desplazar (`ScrollParallax`), filas que aparecen (`cr-fade`), barras que crecen, cifras que
  cuentan hasta su valor, dona y medidor animados, menús y diálogos con "pop", avisos (toasts),
  esqueletos con brillo y elevación al pasar el puntero. Todo respeta «reducir movimiento».
- **Fondo y cristal:** imagen de fondo (`assets/backgrounds/fondo.jpg`) con un velo para la legibilidad. Las tarjetas parecen
  cristal esmerilado sin desenfoque en tiempo real: pintan el trozo de `fondo_esmerilado.jpg` (la misma imagen ya
  desenfocada) que queda detrás de ellas (`Frost` en `lib/ui/glass.dart`). Para cambiar el fondo, sustituye ambos archivos.
- **Tarjetas y gráficos:** tarjetas tipo «pipeline» (`DealCard`, `SummaryTile`, `CardGrid`, `BoardColumn` en
  `lib/ui/deal_card.dart`) en Movimientos, Cuentas, Metas, Recurrentes y Categorías; flujo de ingresos y gastos con curvas
  monótonas y reparto del gasto en barra segmentada (`lib/screens/flow_chart.dart`).
- **Estilo «Relay» (solo Flutter):** fondo estático (sin efectos que se repinten en cada fotograma), titulares con la palabra
  destacada en serif cursiva (`CrHeadline`, marca con `*asteriscos*`), etiquetas y metadatos en monoespaciada (`CrTag`,
  `CrText.mono`), botones píldora en fucsia neón, barras isométricas en la tendencia, panel en perspectiva en el acceso y entrada
  de la app con el logo (`lib/ui/intro.dart`). **Logo:** `AlveaLogo` (`lib/ui/logo.dart`) lo dibuja en vectorial a partir de
  los SVG de `brand/`; los iconos de la PWA y el favicon de `web/` salen de los mismos archivos. Los acentos neón se derivan de los fucsias de `tokens.json` (`CrAccent`), sin tonos
  nuevos: la web React no cambia.
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

Licencias: Manrope, Instrument Serif y JetBrains Mono (SIL OFL, textos en `assets/fonts/OFL-*.txt`) y un subconjunto de
DejaVu Sans para símbolos (licencia libre de Bitstream Vera/DejaVu).
