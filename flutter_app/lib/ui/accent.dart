import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'tokens.g.dart';

// Personalización de colores: el usuario elige el color de acento de la app y la intensidad del
// fondo. Los tonos salen de girar el fucsia de la paleta (misma luz y saturación, otro matiz), así
// todo el diseño conserva sus proporciones; el fondo y el cristal se tiñen con el mismo giro.

/// Un color de acento. [hue] en grados (el fucsia de la paleta está en [baseHue]).
class AccentChoice {
  const AccentChoice(this.id, this.label, this.hue, this.swatch);
  final String id, label;
  final double hue;

  /// Color de la muestra en el selector.
  final Color swatch;

  bool get isDefault => hue == baseHue;
}

/// Matiz del fucsia original (#E879F9).
const baseHue = 292.0;

/// El de siempre.
const fuchsiaAccent = AccentChoice('fucsia', 'Fucsia', baseHue, Color(0xFFE879F9));

const accentChoices = [
  fuchsiaAccent,
  AccentChoice('violeta', 'Violeta', 262, Color(0xFFA78BFA)),
  AccentChoice('azul', 'Azul', 218, Color(0xFF60A5FA)),
  AccentChoice('turquesa', 'Turquesa', 178, Color(0xFF2DD4BF)),
  AccentChoice('esmeralda', 'Esmeralda', 150, Color(0xFF34D399)),
  AccentChoice('ambar', 'Ámbar', 36, Color(0xFFFBBF24)),
  AccentChoice('coral', 'Coral', 352, Color(0xFFFB7185)),
];

AccentChoice accentById(String? id) => accentChoices.where((a) => a.id == id).firstOrNull ?? accentChoices.first;

/// Intensidad del fondo: cuánta luz de color hay detrás del cristal.
enum GlowLevel {
  soft('Suave', 0.45, 0.55),
  normal('Normal', 1, 1),
  vivid('Intensa', 1.6, 1.35);

  const GlowLevel(this.label, this.glow, this.saturation);
  final String label;

  /// Multiplica la opacidad de las luces del fondo.
  final double glow;

  /// Saturación de la imagen de fondo (1 = original).
  final double saturation;
}

GlowLevel glowById(String? id) => GlowLevel.values.where((g) => g.name == id).firstOrNull ?? GlowLevel.normal;

/// Gira el matiz de un color conservando su luz, saturación y opacidad.
Color shiftHue(Color c, double degrees) {
  if (degrees == 0) return c;
  final hsl = HSLColor.fromColor(c);
  return hsl.withHue((hsl.hue + degrees) % 360).toColor().withValues(alpha: c.a);
}

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

/// Paleta con el acento y la intensidad elegidos. Con los valores por defecto devuelve [p] tal cual.
CrPalette tintPalette(CrPalette p, AccentChoice accent, GlowLevel glow) {
  if (accent.isDefault && glow == GlowLevel.normal) return p;
  final d = accent.hue - baseHue;
  final dark = p.bg.computeLuminance() < 0.2;
  Color h(Color c) => shiftHue(c, d);

  var brand = h(p.brand);
  var brandFill = h(p.brandFill);
  var brandFill2 = h(p.brandFill2);
  var focus = h(p.focus);
  var chart1 = h(p.chart1);
  if (dark) {
    // El texto de marca va sobre el fondo oscuro; el neón lleva texto oscuro encima
    brand = ensureContrast(brand, p.bg, ratio: 7, darken: false);
    focus = ensureContrast(focus, const Color(0xFF1A0420), darken: false);
  } else {
    // En claro el texto de marca va sobre blanco y el relleno lleva texto blanco
    brand = ensureContrast(brand, p.bg);
    brandFill = ensureContrast(brandFill, p.onBrand);
    brandFill2 = ensureContrast(brandFill2, p.onBrand);
    focus = ensureContrast(focus, p.bg, ratio: 3);
    chart1 = ensureContrast(chart1, p.bg, ratio: 3);
  }
  return CrPalette(
    bg: h(p.bg),
    bgGlowBrand: _alpha(h(p.bgGlowBrand), glow.glow),
    bgGlowAlt: _alpha(h(p.bgGlowAlt), glow.glow),
    glass: h(p.glass),
    glassStrong: h(p.glassStrong),
    glassBorder: h(p.glassBorder),
    glassHighlight: p.glassHighlight,
    hairline: p.hairline,
    surfaceSolid: h(p.surfaceSolid),
    ink: p.ink,
    inkMuted: p.inkMuted,
    inkFaint: p.inkFaint,
    brand: brand,
    brandSoft: h(p.brandSoft),
    onBrand: p.onBrand,
    brandFill: brandFill,
    brandFill2: brandFill2,
    amber: p.amber,
    amberSoft: p.amberSoft,
    positive: p.positive,
    positiveSoft: p.positiveSoft,
    negative: p.negative,
    negativeSoft: p.negativeSoft,
    focus: focus,
    chart1: chart1,
    chart2: p.chart2,
    chart3: p.chart3,
    chart4: h(p.chart4),
    chart5: p.chart5,
    shadowGlass: p.shadowGlass,
    shadowBrand: _shadow(p.shadowBrand, h(p.shadowBrand.color)),
    shadowLift: p.shadowLift,
  );
}

/// Filtro para la imagen de fondo y el cristal: gira el matiz y ajusta la saturación (null = sin cambio).
ColorFilter? backdropFilter(AccentChoice accent, GlowLevel glow) {
  if (accent.isDefault && glow == GlowLevel.normal) return null;
  return ColorFilter.matrix(_multiply(_hueRotate(accent.hue - baseHue), _saturate(glow.saturation)));
}

// Matrices de color 4×5 (como feColorMatrix de SVG)
List<double> _hueRotate(double degrees) {
  final a = degrees * math.pi / 180;
  final c = math.cos(a), s = math.sin(a);
  return [
    0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0, //
    0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0,
    0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _saturate(double s) => [
  0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
  0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
  0, 0, 0, 1, 0,
];

/// a·b para matrices de color 4×5 (con la fila implícita 0 0 0 0 1).
List<double> _multiply(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var r = 0; r < 4; r++) {
    for (var col = 0; col < 5; col++) {
      var v = col == 4 ? a[r * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[r * 5 + k] * b[k * 5 + col];
      }
      out[r * 5 + col] = v;
    }
  }
  return out;
}
