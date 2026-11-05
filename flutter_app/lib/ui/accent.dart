import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'tokens.g.dart';

// Personalización de colores: la app es monocroma (blanco, negro y gris). El usuario elige un matiz muy
// leve para los grises (neutro, cálido o frío) y la intensidad de la luz del fondo. Nunca hay color
// saturado: el matiz solo tiñe un poco los grises para que se sientan más suaves o más fríos.

/// Un tono de los grises. [hue] en grados y [saturation] (0–1, muy baja) del tinte; 0 = gris puro.
class AccentChoice {
  const AccentChoice(this.id, this.label, this.hue, this.saturation, this.swatch);
  final String id, label;
  final double hue, saturation;

  /// Color de la muestra en el selector.
  final Color swatch;

  bool get isDefault => id == 'neutro';

  /// Tiñe un gris conservando su luz y opacidad.
  Color tint(Color c) {
    if (saturation == 0) return c;
    final hsl = HSLColor.fromColor(c);
    // Los extremos (blanco y negro puros) apenas se tiñen; los grises medios, un poco más
    final k = 1 - (hsl.lightness - 0.5).abs() * 1.2;
    return hsl.withHue(hue).withSaturation((saturation * k).clamp(0.0, 1.0)).toColor().withValues(alpha: c.a);
  }
}

/// Grises puros, el de siempre.
const neutralAccent = AccentChoice('neutro', 'Neutro', 0, 0, Color(0xFFE5E5E5));

/// Compatibilidad: el antiguo acento por defecto.
const fuchsiaAccent = neutralAccent;

const accentChoices = [
  neutralAccent,
  AccentChoice('calido', 'Cálido', 38, 0.10, Color(0xFFE8E2D8)),
  AccentChoice('frio', 'Frío', 214, 0.12, Color(0xFFDCE2EA)),
  AccentChoice('grafito', 'Grafito', 0, 0, Color(0xFFA3A3A3)),
];

AccentChoice accentById(String? id) => accentChoices.where((a) => a.id == id).firstOrNull ?? accentChoices.first;

/// Intensidad del fondo: cuánta luz hay detrás del cristal.
enum GlowLevel {
  soft('Suave', 0.45, 0.82),
  normal('Normal', 1, 1),
  vivid('Intensa', 1.6, 1.18);

  const GlowLevel(this.label, this.glow, this.brightness);
  final String label;

  /// Multiplica la opacidad de las luces del fondo.
  final double glow;

  /// Brillo de la imagen de fondo (1 = original).
  final double brightness;
}

GlowLevel glowById(String? id) => GlowLevel.values.where((g) => g.name == id).firstOrNull ?? GlowLevel.normal;

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Oscurece (o aclara) [c] hasta que contraste al menos [ratio] con [against].
Color ensureContrast(Color c, Color against, {double ratio = 4.5, bool darken = true}) {
  var hsl = HSLColor.fromColor(c);
  for (var i = 0; i < 40 && contrastRatio(hsl.toColor(), against) < ratio; i++) {
    hsl = hsl.withLightness((hsl.lightness + (darken ? -0.02 : 0.02)).clamp(0.0, 1.0));
  }
  return hsl.toColor().withValues(alpha: c.a);
}

BoxShadow _shadow(BoxShadow s, Color color) =>
    BoxShadow(offset: s.offset, blurRadius: s.blurRadius, spreadRadius: s.spreadRadius, color: color);

Color _alpha(Color c, double k) => c.withValues(alpha: (c.a * k).clamp(0.0, 1.0));

/// Paleta con el tono y la intensidad elegidos. Con los valores por defecto devuelve [p] tal cual.
CrPalette tintPalette(CrPalette p, AccentChoice accent, GlowLevel glow) {
  if (accent.isDefault && glow == GlowLevel.normal) return p;
  final dark = p.bg.computeLuminance() < 0.2;
  Color t(Color c) => accent.tint(c);
  var brand = t(p.brand), brandFill = t(p.brandFill), brandFill2 = t(p.brandFill2), focus = t(p.focus);
  if (accent.id == 'grafito') {
    // Acento gris medio en lugar de blanco (o negro): más sobrio, con contraste suficiente
    brand = dark ? const Color(0xFFD4D4D4) : const Color(0xFF3A3A3A);
    brandFill = dark ? const Color(0xFFBDBDBD) : const Color(0xFF454545);
    brandFill2 = dark ? const Color(0xFF9E9E9E) : const Color(0xFF5A5A5A);
    focus = dark ? const Color(0xFFD4D4D4) : const Color(0xFF3A3A3A);
  }
  return CrPalette(
    bg: t(p.bg),
    bgGlowBrand: _alpha(t(p.bgGlowBrand), glow.glow),
    bgGlowAlt: _alpha(t(p.bgGlowAlt), glow.glow),
    glass: t(p.glass),
    glassStrong: t(p.glassStrong),
    glassBorder: t(p.glassBorder),
    glassHighlight: p.glassHighlight,
    hairline: p.hairline,
    surfaceSolid: t(p.surfaceSolid),
    ink: t(p.ink),
    inkMuted: t(p.inkMuted),
    inkFaint: t(p.inkFaint),
    brand: brand,
    brandSoft: t(p.brandSoft),
    onBrand: p.onBrand,
    brandFill: brandFill,
    brandFill2: brandFill2,
    amber: t(p.amber),
    amberSoft: t(p.amberSoft),
    positive: t(p.positive),
    positiveSoft: t(p.positiveSoft),
    negative: t(p.negative),
    negativeSoft: t(p.negativeSoft),
    focus: focus,
    chart1: t(p.chart1),
    chart2: t(p.chart2),
    chart3: t(p.chart3),
    chart4: t(p.chart4),
    chart5: t(p.chart5),
    shadowGlass: p.shadowGlass,
    shadowBrand: _shadow(p.shadowBrand, t(p.shadowBrand.color)),
    shadowLift: p.shadowLift,
  );
}

/// Filtro para la imagen de fondo y el cristal: tiñe levemente y ajusta el brillo (null = sin cambio).
ColorFilter? backdropFilter(AccentChoice accent, GlowLevel glow) {
  if (accent.saturation == 0 && glow == GlowLevel.normal) return null;
  final w = accent.tint(const Color(0xFF999999));
  final b = glow.brightness;
  // Multiplica cada canal por su peso relativo al gris (así un gris neutro queda igual)
  double k(double ch) => b * ch / 0.6;
  return ColorFilter.matrix([
    k(w.r), 0, 0, 0, 0, //
    0, k(w.g), 0, 0, 0,
    0, 0, k(w.b), 0, 0,
    0, 0, 0, 1, 0,
  ]);
}
