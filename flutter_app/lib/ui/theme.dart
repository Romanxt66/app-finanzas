import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';

const fontFamily = 'Manrope';

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
  static TextStyle caption(Color c) => _s(12, 16, FontWeight.w600, c, 0.02);
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
