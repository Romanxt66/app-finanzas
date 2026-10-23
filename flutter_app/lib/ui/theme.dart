import 'package:flutter/material.dart';

/// Sistema "Cristal" (design/tokens.json): vidrio esmerilado sobre fondo con resplandores.
class Cristal extends ThemeExtension<Cristal> {
  const Cristal({
    required this.bg,
    required this.glowMint,
    required this.glowAmber,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.hairline,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.mint,
    required this.mintSoft,
    required this.onMint,
    required this.amber,
    required this.amberSoft,
    required this.positive,
    required this.negative,
    required this.negativeSoft,
  });

  final Color bg,
      glowMint,
      glowAmber,
      glass,
      glassStrong,
      glassBorder,
      hairline,
      surface;
  final Color ink, inkMuted, inkFaint, mint, mintSoft, onMint, amber, amberSoft;
  final Color positive, negative, negativeSoft;

  static const dark = Cristal(
    bg: Color(0xFF0A0E13),
    glowMint: Color(0x4734D399),
    glowAmber: Color(0x33F59E0B),
    glass: Color(0x0FFFFFFF),
    glassStrong: Color(0x1CFFFFFF),
    glassBorder: Color(0x1FFFFFFF),
    hairline: Color(0x14FFFFFF),
    surface: Color(0xFF161D26),
    ink: Color(0xFFF1F5F8),
    inkMuted: Color(0xFF9AA7B4),
    inkFaint: Color(0xFF6B7886),
    mint: Color(0xFF34D399),
    mintSoft: Color(0x2934D399),
    onMint: Color(0xFF032419),
    amber: Color(0xFFFBBF24),
    amberSoft: Color(0x29FBBF24),
    positive: Color(0xFF6EE7B7),
    negative: Color(0xFFFDA4AF),
    negativeSoft: Color(0x24FDA4AF),
  );

  static const light = Cristal(
    bg: Color(0xFFEAF0F4),
    glowMint: Color(0x4D10B981),
    glowAmber: Color(0x42F59E0B),
    glass: Color(0x8CFFFFFF),
    glassStrong: Color(0xC7FFFFFF),
    glassBorder: Color(0xD9FFFFFF),
    hairline: Color(0x140E1620),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF0E1620),
    inkMuted: Color(0xFF4C5A68),
    inkFaint: Color(0xFF6F7C89),
    mint: Color(0xFF047857),
    mintSoft: Color(0x1F047857),
    onMint: Color(0xFFFFFFFF),
    amber: Color(0xFFB45309),
    amberSoft: Color(0x1FB45309),
    positive: Color(0xFF047857),
    negative: Color(0xFFBE123C),
    negativeSoft: Color(0x1ABE123C),
  );

  @override
  Cristal copyWith() => this;

  @override
  Cristal lerp(Cristal? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension CristalContext on BuildContext {
  Cristal get c => Theme.of(this).extension<Cristal>()!;
}

const radiusSm = 12.0, radiusMd = 18.0, radiusLg = 28.0;
const fontFamily = 'Manrope';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? Cristal.dark : Cristal.light;
  final scheme = ColorScheme.fromSeed(seedColor: c.mint, brightness: brightness)
      .copyWith(
        primary: c.mint,
        onPrimary: c.onMint,
        surface: c.surface,
        onSurface: c.ink,
        error: c.negative,
      );
  OutlineInputBorder border(Color color, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radiusSm),
    borderSide: BorderSide(color: color, width: w),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: c.surface,
    extensions: [c],
    textTheme: Typography.material2021().black.apply(
      fontFamily: fontFamily,
      bodyColor: c.ink,
      displayColor: c.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.glass,
      labelStyle: TextStyle(color: c.inkMuted),
      enabledBorder: border(c.glassBorder),
      focusedBorder: border(c.mint, 2),
      errorBorder: border(c.negative),
      focusedErrorBorder: border(c.negative, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.mint,
        foregroundColor: c.onMint,
        minimumSize: const Size(44, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.mint,
        minimumSize: const Size(44, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(44, 48),
        shape: const StadiumBorder(),
        side: BorderSide(color: c.glassBorder),
      ),
    ),
    dividerColor: c.hairline,
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface,
      contentTextStyle: TextStyle(color: c.ink, fontFamily: fontFamily),
    ),
  );
}
