# Catálogo de componentes (Alvea 2, Flutter)

Rutas relativas a `flutter_app/lib/`. Antes de crear un widget nuevo, busca aquí uno que sirva.

## Estructura de página

| Widget | Archivo | Para qué |
|---|---|---|
| `PageScaffold(children:)` | `ui/page.dart` | Contenido de cualquier pantalla: columna centrada, separación de 16 y entrada escalonada |
| `PageHead(título, headline: 'Texto *acento*.', lead:, actions:)` | `ui/widgets.dart` | Cabecera: etiqueta mono, titular con serif cursiva, acciones a la derecha, paralaje al desplazar |
| `GridCols(children:)` | `ui/page.dart` | Dos columnas en ancho, una en móvil |
| `FormGrid(children:, minWidth:)` / `Stack12` | `ui/page.dart` | Rejilla de formulario / pila con separación 12 |
| `SectionTitle('Título')` | `ui/widgets.dart` | Título de sección fuera de tarjeta |

## Superficies y tarjetas

| Widget | Archivo | Para qué |
|---|---|---|
| `Glass(child:, strong:, radius:, padding:, lift:, onTap:, borderColor:)` | `ui/glass.dart` | Base de todo: cristal esmerilado sobre la imagen de fondo |
| `CrCard(title:, meta:, action:, child:)` | `ui/widgets.dart` | Tarjeta con título (meta = texto mono a la derecha) |
| `DealCard(...)` | `ui/deal_card.dart` | Tarjeta tipo «pipeline» para cualquier elemento de una lista (ver abajo) |
| `SummaryTile(label:, value:, icon:, color:, note:, progress:, selected:, onTap:)` | `ui/deal_card.dart` | Resumen de cabecera con icono de color; tocable para filtrar |
| `CardGrid(children:, minWidth:, maxColumns:)` | `ui/deal_card.dart` | Cuadrícula adaptable de tarjetas del mismo ancho, con aparición escalonada |
| `BoardColumn(title:, color:, count:, total:, children:)` | `ui/deal_card.dart` | Columna de tablero («● Gastos 12 · $1.200») |
| `BalanceCard`, `StatTile`, `BudgetBar`, `ProgressCard` | `ui/widgets.dart` | Saldo total, KPI, presupuesto, progreso |
| `Skeleton(lines:, height:)` | `ui/widgets.dart` | Cargando (cristal con brillo) |
| `CrEmpty('texto')`, `ErrorText(error)` | `ui/widgets.dart` | Vacío y error |

### `DealCard`

```dart
DealCard(
  leading: BankLogo(name: a.name, fallback: initials(a.name), color: color), // o avatar: 'CP'
  accent: color,                 // avatar, línea de progreso y mini gráfica
  title: a.name,
  subtitle: 'Banco · COP',       // mono, una línea
  eyebrow: 'saldo',              // etiqueta mono sobre la cifra
  value: formatMoney(a.balance, a.currency),
  valueColor: a.balance < 0 ? c.negative : null,
  spark: serie,                  // List<double>, opcional (mini gráfica a la derecha)
  trailing: 'de $3.000',         // texto mono a la derecha de la cifra si no hay mini gráfica
  progress: 0.38,                // línea fina bajo la cifra
  chips: [DealChip('Banco', dot: true, color: color), DealChip('26 oct', icon: 'calendar')],
  actions: [CardAction(icon: 'edit', tooltip: 'Renombrar', onPressed: ...),
            CardAction(icon: 'trash', tooltip: 'Eliminar', danger: true, onPressed: ...)],
  footer: Wrap(children: [CrButton(...)]), // botones de la tarjeta (p. ej. Aportar/Retirar)
  dimmed: archivada,
  semanticLabel: 'Nequi, saldo $350.000',
)
```

Utilidades: `initials(texto)`, `txColor(c, tipo)`, `monotonePath(puntos)`, `MiniSpark(data:, color:)`.

## Gráficos

| Widget | Archivo | Para qué |
|---|---|---|
| `FlowCard(trend:, currency:, byCategory:, names:)` | `screens/flow_chart.dart` | Flujo de ingresos/gastos con barra segmentada del gasto |
| `FlowChart(trend:, currency:)` | `screens/flow_chart.dart` | Solo el gráfico de curvas con tooltip |
| `CategoryStrip(rows:, names:, currency:)` | `screens/flow_chart.dart` | Reparto en barra segmentada con etiquetas y % |
| `Gauge`, `Donut`, `Sparkline`, `GrowBar` | `ui/widgets.dart`, `ui/motion.dart` | Medidor, dona, línea pequeña, barra que crece |

## Controles

| Widget | Para qué |
|---|---|
| `CrButton(label:, icon:, variant: CrButtonVariant.primary/glass/ghost/danger, small:, onPressed:)` | Botones (píldora). Primario = fucsia neón con halo |
| `CrTextField`, `CrPasswordField`, `CrSelect<T>(label:, value:, options: [(valor, 'Etiqueta')], onChanged:)` | Campos (`ui/inputs.dart`) |
| `CrSegmented<T>(options:, value:, onChanged:)` | Píldoras de filtro (envuélvelo en `Align(centerLeft)` para que no se estire) |
| `CrDateField`, `CrMonthField`, `CrCheckbox` | Fechas, mes, casilla |
| `CurrencySelect`, `CategorySelect` | En `screens/features.dart` |
| `CrBadge(texto, tone: Tone.positive/negative/brand/amber/…)`, `Delta(%)`, `CrChip('icono')`, `CrTag('texto')` | Insignias, variación, icono en chip, etiqueta con punto |
| `CardAction(icon:, tooltip:, danger:)` | Acción discreta dentro de una tarjeta |
| `showCrDialog`, `showConfirm` | Diálogos (`ui/dialogs.dart`) |

Iconos disponibles en `CrIcon('nombre')` (`ui/icons.dart`): home chart wallet card user plus send
receive swap up down salary target eye tag list logout edit trash archive restore check sun moon
download mail lock arrow shield fingerprint key search chevron chevrons play calendar. Para uno
nuevo, añade su trazo SVG (caja 24×24) al mapa.

## Marca y personajes

| Widget | Archivo | Para qué |
|---|---|---|
| `AlveaLogo(size:)` | `ui/logo.dart` | Logo de Alvea en vectorial |
| `MoodFace(expression:, size:, lively:, followPointer:)` | `ui/mood_face.dart` | Gotita de malvavisco; `GlobalKey<MoodFaceState>().currentState?.boing()` para que salte |
| `FinanceMood.faces`, `spendingMoods` | `screens/insights.dart` | Expresiones de Alvi por nivel y caritas del ánimo del gasto |
| `BankLogo(name:, fallback:)`, `bankFor(nombre)`, `bankBrands` | `ui/banks.dart` | Insignia del banco reconocido por el nombre |

## Movimiento (`ui/motion.dart`)

`Rise`, `FadeIn`, `ScrollParallax`, `PressScale`, `CountUp`, `AnimatedMoney`, `GrowBar`,
curvas `crEase` y `crPopEase`. Datos asíncronos: `Query<T>(load:, deps:, builder:)` (`ui/query.dart`).
