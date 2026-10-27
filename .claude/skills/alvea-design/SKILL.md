---
name: alvea-design
description: Sistema de diseño de Alvea 2 (app Flutter en flutter_app/, rama cli/flutter-app) — fondo con imagen y cristal esmerilado, tarjetas tipo «pipeline», titulares con acento en serif, fucsia neón, Alvi (la gotita de malvavisco), gráficos con curvas monótonas y animaciones. Úsala SIEMPRE antes de crear o modificar cualquier pantalla, tarjeta, gráfico, color, animación o texto visible de la app Flutter, y para revisar si un cambio respeta el estilo.
---

# Diseño de Alvea 2 (Flutter)

Alvea es una app de finanzas personales. Esta skill describe el estilo visual de la versión
Flutter (`flutter_app/`, desplegada como alvea2 desde la rama `cli/flutter-app`). La web React
(`frontend/`, rama `main`) tiene su propio diseño: **no** apliques esto ahí.

Antes de tocar código lee la referencia que corresponda:
- `references/componentes.md` — catálogo de widgets con su uso (qué usar para cada cosa).
- `references/verificacion.md` — cómo comprobar el cambio (pruebas, build y capturas).

## Principios

1. **Solo presentación.** Los cambios de diseño no tocan `lib/core/` (API, estado, modelos) ni el
   backend. Si una idea necesita datos nuevos, es otra tarea: sepárala.
2. **Oscuro, translúcido y luminoso.** Fondo con imagen desenfocada, tarjetas de cristal
   esmerilado que dejan ver la luz de detrás, acentos en fucsia neón. Nada de bloques opacos.
3. **Fluido antes que vistoso.** La web corre con CanvasKit: nada que se repinte a pantalla
   completa en cada fotograma. Ver «Rendimiento».
4. **Todo en español**, con tono cercano y frases cortas (ver «Textos»).
5. **Accesible:** etiquetas `Semantics` en lo que no sea texto, contraste ≥ 4,5:1 en texto y
   respeto a «reducir movimiento» (`context.reduceMotion`).

## Color

- Los colores salen de `design/tokens.json` → `lib/ui/tokens.g.dart` (generado con
  `dart run tool/gen_tokens.dart`; **nunca** se edita a mano, la CI lo comprueba).
- Accede a la paleta con `context.c` (`CrPalette`). Acentos derivados en `CrAccent`
  (`lib/ui/theme.dart`): `c.neon` (fucsia de acción), `c.onNeon` (texto sobre neón),
  `c.neonGlow` (halo), `c.panel` (fondo de chips/píldoras), `c.isDark`.
- No inventes hex sueltos para la UI. Excepciones con color propio y documentado: las caritas de
  ánimo (`FinanceMood.faces`, `spendingMoods`), las insignias de bancos (`bankBrands`) y la
  imagen de fondo.
- Tipos de movimiento: `txColor(c, type)` — ingreso `positive`, gasto `neon`, transferencia `chart4`.
  Tipos de cuenta: `accountTypeColor(c, type)`.
- Series de gráficos: `c.neon`, `c.chart2`, `c.chart3`, `c.chart4`, `c.amber`.

## Tipografía (`CrText`)

| Uso | Estilo |
|---|---|
| Titular de página | `CrHeadline('Texto con *acento*.')` dentro de `PageHead` — la parte entre asteriscos va en serif cursiva (Instrument Serif) |
| Cifras grandes | `CrText.display(color, size: 22–48)` (Manrope 700, cifras tabulares); animadas con `AnimatedMoney` o `CountUp` |
| Etiquetas de sistema, metadatos, chips | `CrText.mono(color, size: 10.5–11.5)` (JetBrains Mono) y en **minúsculas** («saldo», «ingresos de 6 meses») |
| Texto normal | `CrText.body`, `label`, `heading` |
| Frase destacada | `CrText.serif` (con moderación) |

Fuentes empaquetadas en `assets/fonts` (sin CDN: lo exige la CSP de nginx).

## Superficies: cristal esmerilado

- Toda tarjeta es un `Glass` (o algo construido sobre él: `CrCard`, `DealCard`, `SummaryTile`,
  `StatTile`, `BalanceCard`…). **No** pintes rectángulos opacos con `Container(color: …)` como
  tarjeta: rompen el efecto (así eran los marcadores de carga «oscuros» que hubo que arreglar).
- El fondo (`CrBackdrop`, `lib/ui/glass.dart`) muestra `assets/backgrounds/fondo.jpg` desenfocada
  con un velo. Las tarjetas pintan el trozo de `fondo_esmerilado.jpg` que tienen detrás (`Frost` /
  `RenderFrost`) y encima un tinte (`frostTint`: 34 % normal, 46 % `strong`) y un reflejo tenue.
- Para formas no rectangulares (p. ej. el bocadillo de Alvi) recorta con `ClipPath` y envuelve en
  `Frost(image: scope.image!, backdrop: scope.backdrop, …)` usando `FrostScope.maybeOf(context)`.
- **Sin sombras** bajo el cristal translúcido (se verían a través). Para destacar usa borde de
  color (`borderColor`) o halo exterior desenfocado.
- Cambiar el fondo: reemplaza las dos imágenes o regenéralas con
  `python3 tool/make_background.py assets/backgrounds`.
- Radios: `radiusSm 10`, `radiusMd 14`, `radiusLg 20`, tarjetas tipo pipeline `16`, píldoras
  `radiusPill`. Espaciado: `space1…space6` (4, 8, 12, 16, 20, 32).

## Composición de pantallas

```dart
PageScaffold(children: [            // columna centrada de 1040 px, entrada escalonada (Rise)
  PageHead('Cuentas', headline: 'Tus cuentas, *de un vistazo*.', actions: [CrButton(...)]),
  // resúmenes → filtros → contenido
  CardGrid(minWidth: 150, children: [SummaryTile(...), ...]),
  Align(alignment: Alignment.centerLeft, child: CrSegmented(...)),
  CardGrid(minWidth: 240, children: [DealCard(...), ...]),
]);
```

- Cada pantalla abre con `PageHead` (etiqueta mono + titular con acento + acciones a la derecha).
- Listas de elementos → **tarjetas** (`DealCard` en `CardGrid`), no filas. En pantallas anchas con
  categorías claras usa columnas de tablero (`BoardColumn`), como Movimientos por tipo; si solo
  hay una columna o en móvil, vuelve a `CardGrid`.
- Formularios de alta: plegados tras un botón primario («Nueva cuenta») cuando ya hay datos.
- Vacío → `CrCard(child: CrEmpty('Qué falta y cómo conseguirlo.'))`. Cargando → `Skeleton`.
  Error → `ErrorText(error)`.
- Móvil (< `isWide`): una columna, barra inferior; resúmenes pequeños en 2 columnas
  (`CardGrid(minWidth: 150)`); botones de acción de tarjeta en la fila inferior para no cortar
  títulos.

## Movimiento

- Curvas `crEase` / `crPopEase`. Duraciones: 200–300 ms (estados), 520 ms (entradas),
  900–1200 ms (dibujo de gráficos).
- Entradas: `Rise` (ya lo aplica `PageScaffold`; los módulos fuera de pantalla aparecen al
  desplazar), `FadeIn` para elementos de lista (retardo `30–40 ms × índice`, máx. ~8),
  `ScrollParallax` en titulares.
- Pulsación: `PressScale`. Cifras: `AnimatedMoney`/`CountUp`. Barras: `GrowBar(glow: true)`.
- Gráficos de líneas: **siempre** `monotonePath` (no rebota bajo cero ni inventa picos), área con
  degradado, línea con halo, se dibujan de izquierda a derecha al entrar.
- Toda animación continua debe detenerse con `context.reduceMotion` y vivir en su propio
  `RepaintBoundary`.

## Rendimiento (obligatorio)

- **Nunca** `BackdropFilter` en tarjetas, barras o campos (desenfoque en tiempo real = app
  trabada). Solo se permite en diálogos y menús desplegables, que son momentáneos.
- Nada animado a pantalla completa ni fondos que se repinten por fotograma.
- `MaskFilter.blur` solo en elementos pequeños (halos de líneas, logos, caritas).
- Si algo pinta el fondo según su posición (como `Frost`), debe repintarse al desplazar: las capas
  de opacidad de `Rise` se mueven sin repintar su contenido.

## Alvi y las caritas

- Alvi es la gotita de malvavisco del resumen (`MoodFace` en `lib/ui/mood_face.dart`): pastel,
  mate, con bracitos y piececitos. Habla desde un bocadillo de cristal (`FinanceMoodCard`).
- Expresiones = `FaceExpression` (números interpolables: `smile`, `eyeHappy`, `bounce`,
  `shiver`, `sweat`, `tear`, `sparkle`…). Nuevas caritas: añade una expresión, no otro painter.
- Sin emojis de fuente: en la web dependerían de fuentes externas. Dibuja con `MoodFace`/iconos.

## Textos

- Español neutro y cercano, tuteo: «Tu dinero, *claro*.», «¿Te tienta algo?».
- Titulares de página con una palabra o expresión en `*acento*`.
- Etiquetas mono en minúsculas; cifras con `formatMoney(valor, moneda)`; porcentajes con
  `formatPercent`; fechas con `formatDate`.
- Estados vacíos explican qué falta y cómo conseguirlo, sin culpar.

## Bancos y logos

- `BankLogo(name:, fallback: initials(name))` reconoce la entidad por el nombre de la cuenta
  (`bankFor`, palabras completas) y muestra su insignia de color. Los logos oficiales son marcas
  registradas: no se descargan ni se incluyen; si el usuario aporta uno, va en
  `assets/banks/<id>.png` y su id en `bankLogoAssets`.

## Antes de entregar

1. `flutter analyze` sin incidencias y `flutter test` en verde (añade pruebas para lógica nueva:
   cálculos, textos, estados).
2. `dart format` **solo** en los archivos que tocaste (el repo usa `page_width: 140`; formatear
   todo genera ruido en archivos ajenos).
3. Revisión visual en escritorio (1366×860) y móvil (390×844), arriba y desplazado — ver
   `references/verificacion.md`.
4. PR a `cli/flutter-app` (no a `main`) describiendo qué cambia visualmente.
