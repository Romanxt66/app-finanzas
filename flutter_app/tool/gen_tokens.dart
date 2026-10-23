// Genera lib/ui/tokens.g.dart desde ../design/tokens.json (fuente única de Cristal).
// Uso: dart run tool/gen_tokens.dart
import 'dart:convert';
import 'dart:io';

String color(String raw, Map<String, String> names) {
  final v = raw.trim();
  if (v.startsWith('{')) return names[v.substring(1, v.length - 1)]!;
  if (v.startsWith('#')) {
    final hex = v.substring(1);
    return 'Color(0xFF${hex.toUpperCase()})';
  }
  final m = RegExp(r'rgba?\(([^)]*)\)').firstMatch(v)!;
  final p = m.group(1)!.split(',').map((s) => s.trim()).toList();
  final a = p.length > 3 ? double.parse(p[3]) : 1.0;
  return 'Color.fromRGBO(${p[0]}, ${p[1]}, ${p[2]}, $a)';
}

String camel(String s) {
  final parts = s.split('-');
  return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// "0 12px 40px rgba(0, 0, 0, 0.45)" -> BoxShadow(...)
String shadow(String raw) {
  final m = RegExp(r'^(-?\d+)(?:px)?\s+(-?\d+)(?:px)?\s+(\d+)(?:px)?\s+(rgba?\(.*\)|#\w+)$').firstMatch(raw.trim())!;
  return 'BoxShadow(offset: Offset(${m.group(1)}, ${m.group(2)}), blurRadius: ${m.group(3)}, color: ${color(m.group(4)!, {})})';
}

void main() {
  final json = jsonDecode(File('../design/tokens.json').readAsStringSync()) as Map<String, dynamic>;
  final tokens = (json['color'] as Map)['tokens'] as List;
  final out = StringBuffer()
    ..writeln('// GENERADO por tool/gen_tokens.dart desde design/tokens.json. No editar a mano.')
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln()
    ..writeln('class CrPalette {')
    ..writeln('  const CrPalette({');
  for (final t in tokens) {
    out.writeln('    required this.${camel(t['name'])},');
  }
  for (final s in (json['shadow'] as Map)['tokens'] as List) {
    out.writeln('    required this.${camel(s['name'])},');
  }
  out.writeln('  });');
  for (final t in tokens) {
    out.writeln('  final Color ${camel(t['name'])};');
  }
  for (final s in (json['shadow'] as Map)['tokens'] as List) {
    out.writeln('  final BoxShadow ${camel(s['name'])};');
  }
  out.writeln('}');
  for (final theme in ['dark', 'light']) {
    final names = <String, String>{};
    for (final t in tokens) {
      final raw = (t['value'] as Map)[theme] as String;
      if (!raw.startsWith('{')) names[t['name'] as String] = color(raw, names);
    }
    out.writeln('\nconst crPalette${theme[0].toUpperCase()}${theme.substring(1)} = CrPalette(');
    for (final t in tokens) {
      out.writeln('  ${camel(t['name'])}: ${color((t['value'] as Map)[theme] as String, names)},');
    }
    for (final s in (json['shadow'] as Map)['tokens'] as List) {
      out.writeln('  ${camel(s['name'])}: ${shadow((s['value'] as Map)[theme] as String)},');
    }
    out.writeln(');');
  }
  for (final g in ['radius', 'blur', 'spacing']) {
    out.writeln();
    for (final t in (json[g] as Map)['tokens'] as List) {
      final n = (t['name'] as String);
      out.writeln('const double ${camel(n)} = ${(t['value'] as String).replaceAll('px', '')}.0;');
    }
  }
  File('lib/ui/tokens.g.dart').writeAsStringSync(out.toString());
  stdout.writeln('lib/ui/tokens.g.dart generado');
}
