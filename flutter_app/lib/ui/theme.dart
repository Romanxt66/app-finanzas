import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';

const fontFamily = 'Manrope';

/// Serif cursiva para la palabra destacada de un titular («Tu dinero, *claro*.»).
const serifFamily = 'InstrumentSerif';

/// Monoespaciada para etiquetas, metadatos, horas y estados del sistema.
const monoFamily = 'JetBrainsMono';

/// Glifos que Manrope (subconjunto latino) no trae; van incluidos para no pedir tipografías a un CDN.
const fontFallback = ['SymbolsFallback'];

/// Paleta Cristal accesible desde el tema (`context.c`).
class Cr extends ThemeExtension<Cr> {
  const Cr(this.p);
  final CrPalette p;

  @override
  Cr copyWith() => this;

  @override
  Cr lerp(Cr? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Acentos «neón» del diseño Relay, derivados de los fucsias de la paleta (no hay tonos nuevos).
extension CrAccent on CrPalette {
  bool get isDark => bg.computeLuminance() < 0.2;

  /// Relleno de la acción principal: fucsia vivo en oscuro, fucsia profundo en claro.
  Color get neon => isDark ? focus : brandFill;

  /// Texto sobre [neon] (≥ 7:1 en ambos temas).
  Color get onNeon => isDark ? const Color(0xFF1A0420) : onBrand;

  /// Halo de luz bajo los elementos en neón.
  Color get neonGlow => (isDark ? focus : brandFill).withValues(alpha: isDark ? 0.45 : 0.28);

  /// Fondo de los paneles tipo «consola» (más opaco que el vidrio para leer datos).
  Color get panel => isDark ? const Color(0xE60A070D) : const Color(0xEBFFFFFF);
}

extension CrContext on BuildContext {
  CrPalette get c => Theme.of(this).extension<Cr>()!.p;
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
  bool get isWide => MediaQuery.sizeOf(this).width >= 900;
}

/// Estilos tipográficos de tokens.json › type (cifras con números tabulares).
class CrText {
  static const _tab = [FontFeature.tabularFigures()];

  static TextStyle _s(double size, double line, FontWeight w, Color color, [double ls = 0]) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: size,
    height: line / size,
    fontWeight: w,
    color: color,
    letterSpacing: ls * size,
    fontFeatures: _tab,
  );

  static TextStyle amountXl(Color c) => _s(40, 44, FontWeight.w700, c, -0.02);
  static TextStyle amount(Color c) => _s(22, 28, FontWeight.w700, c, -0.01);
  static TextStyle amountSm(Color c) => _s(15, 20, FontWeight.w600, c);
  static TextStyle title(Color c) => _s(20, 26, FontWeight.w700, c);
  static TextStyle heading(Color c) => _s(16, 22, FontWeight.w600, c);
  static TextStyle body(Color c) => _s(15, 22, FontWeight.w500, c);
  static TextStyle label(Color c) => _s(13, 18, FontWeight.w500, c);
  /// Etiqueta de sistema en monoespaciada y minúsculas (`last runs`, `estimate`…).
  static TextStyle overline(Color c) => mono(c, size: 11.5);
  /// Metadatos (fechas, notas, periodicidad): monoespaciada, como las líneas de sistema de «Relay».
  static TextStyle caption(Color c) => mono(c, size: 11.5);

  /// Titular grande, apretado (`The handoffs run`).
  static TextStyle display(Color c, {double size = 40}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: size,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.035 * size,
    color: c,
  );

  /// Palabra destacada en serif cursiva; algo mayor para igualar la altura de la sans.
  static TextStyle serif(Color c, {double size = 40}) => TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: const [fontFamily, ...fontFallback],
    fontStyle: FontStyle.italic,
    fontSize: size * 1.12,
    height: 1.08 / 1.12,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.01 * size,
    color: c,
  );

  /// Texto de sistema en monoespaciada.
  static TextStyle mono(Color c, {double size = 12, FontWeight weight = FontWeight.w400}) => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: const [fontFamily, ...fontFallback],
    fontSize: size,
    height: 1.4,
    fontWeight: weight,
    letterSpacing: 0,
    color: c,
    fontFeatures: _tab,
  );
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? crPaletteDark : crPaletteLight;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.brandFill,
    brightness: brightness,
  ).copyWith(primary: p.brand, onPrimary: p.onBrand, surface: p.surfaceSolid, onSurface: p.ink, error: p.negative);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: p.surfaceSolid,
    extensions: [Cr(p)],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    dividerColor: p.hairline,
    textTheme: Typography.material2021().black.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      bodyColor: p.ink,
      displayColor: p.ink,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.surfaceSolid,
      headerBackgroundColor: p.brandFill,
      headerForegroundColor: p.onBrand,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
    ),
    scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(p.glassBorder)),
  );
}
