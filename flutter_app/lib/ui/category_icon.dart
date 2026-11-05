import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

// Icono de cada categoría según su nombre («Comida», «Transporte», «Netflix»…). Las categorías no guardan
// icono en el servidor: se deduce aquí, y si no se reconoce se usa una etiqueta.

const _rules = <(List<String>, String)>[
  (['arriendo', 'alquiler', 'renta', 'hogar', 'casa', 'vivienda', 'hipoteca', 'administracion'], 'home'),
  (['restaurante', 'domicilio', 'rappi', 'cafe', 'comida rapida', 'almuerzo'], 'restaurant'),
  (['comida', 'mercado', 'supermercado', 'alimenta', 'viveres', 'fruta'], 'food'),
  (['salud', 'medic', 'farmacia', 'eps', 'doctor', 'odontolog', 'seguro medico'], 'health'),
  (['transporte', 'carro', 'auto', 'moto', 'gasolina', 'combustible', 'taxi', 'uber', 'parqueadero', 'peaje'], 'car'),
  (['gimnasio', 'deporte', 'gym', 'futbol', 'tenis', 'yoga'], 'sport'),
  (['regalo', 'cumpleanos', 'donacion', 'navidad'], 'gift'),
  (['educacion', 'colegio', 'universidad', 'curso', 'libro', 'estudio', 'matricula'], 'school'),
  (['viaje', 'vacacion', 'vuelo', 'hotel', 'turismo'], 'travel'),
  (['ocio', 'entretenimiento', 'cine', 'netflix', 'spotify', 'streaming', 'suscripcion', 'juego', 'concierto'], 'film'),
  (['ropa', 'compras', 'shopping', 'tienda', 'calzado'], 'bag'),
  (['servicio', 'luz', 'agua', 'gas', 'energia', 'factura', 'internet'], 'bolt'),
  (['celular', 'telefono', 'plan movil', 'datos'], 'phone'),
  (['sueldo', 'salario', 'nomina', 'quincena'], 'salary'),
  (['freelance', 'trabajo', 'negocio', 'honorario', 'cliente'], 'briefcase'),
  (['ahorro', 'inversion', 'interes', 'rendimiento', 'cdt'], 'target'),
  (['transferencia'], 'swap'),
];

String _fold(String s) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// Nombre del icono (de [CrIcon]) para una categoría.
String categoryIcon(String? name, {String? kind}) {
  if (name == null || name.trim().isEmpty) return kind == 'income' ? 'receive' : 'tag';
  final n = _fold(name);
  for (final (words, icon) in _rules) {
    if (words.any(n.contains)) return icon;
  }
  return kind == 'income' ? 'receive' : 'tag';
}

/// Círculo de cristal con el icono de la categoría (como las fichas de la lista de categorías).
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph(this.name, {super.key, this.kind, this.size = 40, this.icon});
  final String? name;
  final String? kind;
  final double size;

  /// Fuerza un icono concreto en vez de deducirlo del nombre.
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.ink.withValues(alpha: c.isDark ? 0.16 : 0.08),
              c.ink.withValues(alpha: c.isDark ? 0.05 : 0.02),
            ],
          ),
          border: Border.all(color: c.glassBorder),
        ),
        alignment: Alignment.center,
        child: CrIcon(
          icon ?? categoryIcon(name, kind: kind),
          size: size * 0.48,
          color: c.ink,
        ),
      ),
    );
  }
}
