# Cristal — diseño compartido (web y Android)

`tokens.json` es la **fuente única** de colores, tipografía, espaciado, radios, sombras y desenfoques
(sistema de diseño "Cristal": vidrio esmerilado sobre fondo oscuro, claro/oscuro).

- **Web:** `npm run gen:tokens` (en `frontend/`) genera `frontend/src/design/tokens.css`. No editar ese archivo a mano.
  Los componentes viven en `frontend/src/design/` y solo usan variables CSS (`var(--brand)`, `var(--space-4)`…).
- **Flutter (web):** `dart run tool/gen_tokens.dart` (en `flutter_app/`) genera `lib/ui/tokens.g.dart`. Mismos nombres de token.
- **Android:** dos caminos, sin cambiar este archivo:
  1. *Empaquetar la web* con Capacitor: reutiliza todo el frontend. La app ya es móvil primero, respeta
     `safe-area-inset-*` y no depende de CDNs (la fuente Manrope va incluida).
  2. *App nativa (Jetpack Compose)*: leer `tokens.json` y generar el tema (`Color`, `Typography`,
     `Shapes`). Los nombres de token son los mismos en ambas plataformas.
- Cambiar un token = editar `tokens.json` y regenerar; ambas plataformas quedan alineadas.

Reglas del sistema (resumen): módulo = una idea; la cifra manda (`amount-xl`/`amount`, números tabulares);
`brand` (fucsia) es marca y acción, `amber` avisos/metas, `positive`/`negative` solo para dinero con signo o flecha;
vidrio solo sobre `cr-backdrop`; objetivos táctiles de 44 px; foco visible de 2 px.

**Versión fucsia (oct. 2026):** paleta, radios (10/14/20 px), desenfoques (32/44 px) y el estilo `overline` (11 px, mayúsculas,
tracking 0.08em) vienen del sistema "Alvea" diseñado en Claude. Fondo casi negro `#020103`, acción `brand-fill` `#a21caf`
(texto blanco 6.3:1), acento `brand` `#f0abfc` (oscuro) / `#a21cae` (claro). Se añadieron `chart-1…5` para gráficos.
Fuente tipográfica: solo Manrope (incluida, sin CDN); no se usa Inter por la CSP.
