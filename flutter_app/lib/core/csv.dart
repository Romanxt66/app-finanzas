// Lectura de extractos CSV en el navegador (el archivo no se envía hasta confirmar). Port de lib/csv.ts.

enum DateFormatKind { ymd, dmy, mdy }

const delimiters = [',', ';', '\t'];

/// Elige el separador que más aparece fuera de comillas en las primeras líneas.
String detectDelimiter(String text) {
  final sample = text.split(RegExp(r'\r?\n')).take(5).join('\n');
  final counts = {',': 0, ';': 0, '\t': 0};
  var quoted = false;
  for (final ch in sample.split('')) {
    if (ch == '"') {
      quoted = !quoted;
    } else if (!quoted && counts.containsKey(ch)) {
      counts[ch] = counts[ch]! + 1;
    }
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return sorted.first.key;
}

/// Parser RFC 4180 mínimo: comillas dobles, saltos de línea dentro de campos, BOM.
List<List<String>> parseCsv(String input, [String? delimiter]) {
  final sep = delimiter ?? detectDelimiter(input);
  final text = input.replaceFirst('﻿', '');
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"' && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (ch == '"') {
        quoted = false;
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == sep) {
      row.add(field.toString());
      field = StringBuffer();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      rows.add(row);
      row = <String>[];
      field = StringBuffer();
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
}

/// Convierte "1.234,56", "1,234.56", "-$ 1.234", "(500)", "12,5" a número; null si no es un monto.
double? parseCsvAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  var negative = false;
  if (RegExp(r'^\(.*\)$').hasMatch(s)) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  if (s.endsWith('-')) {
    negative = true;
    s = s.substring(0, s.length - 1);
  }
  s = s.replaceAll(RegExp(r'[^\d.,+-]'), '');
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  }
  s = s.replaceFirst(RegExp(r'^\+'), '');
  if (!RegExp(r'^\d[\d.,]*$').hasMatch(s)) return null;
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String? decimalSep;
  if (lastDot >= 0 && lastComma >= 0) {
    decimalSep = lastDot > lastComma ? '.' : ',';
  } else {
    final sep = lastDot >= 0 ? '.' : (lastComma >= 0 ? ',' : null);
    if (sep != null) {
      final parts = s.split(sep);
      decimalSep = (parts.length == 2 && parts[1].length != 3) ? sep : null;
    }
  }
  final integerPart = decimalSep != null ? s.substring(0, s.lastIndexOf(decimalSep)) : s;
  if (!RegExp(r'^\d+$').hasMatch(integerPart) && !RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(integerPart)) {
    return null;
  }
  final normalized = decimalSep != null
      ? s.split(decimalSep == '.' ? ',' : '.').join().replaceFirst(decimalSep, '.')
      : s.replaceAll(RegExp(r'[.,]'), '');
  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite) return null;
  return negative ? -value : value;
}

/// Fecha a YYYY-MM-DD según el formato elegido; null si no es válida (31/02, etc.).
String? parseCsvDate(String raw, DateFormatKind format) {
  final m = RegExp(r'^(\d{1,4})[-/.](\d{1,2})[-/.](\d{1,4})').firstMatch(raw.trim());
  if (m == null) return null;
  final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!), c = int.parse(m.group(3)!);
  var y = 0, mo = 0, d = 0;
  switch (format) {
    case DateFormatKind.ymd:
      (y, mo, d) = (a, b, c);
    case DateFormatKind.dmy:
      (d, mo, y) = (a, b, c);
    case DateFormatKind.mdy:
      (mo, d, y) = (a, b, c);
  }
  if (y < 100) y += 2000;
  final date = DateTime.utc(y, mo, d);
  if (date.year != y || date.month != mo || date.day != d) return null;
  return '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

/// Adivina el formato de fecha mirando si algún valor solo puede ser día-primero o mes-primero.
DateFormatKind guessDateFormat(List<String> samples) {
  if (samples.any((s) => RegExp(r'^\d{4}[-/.]').hasMatch(s.trim()))) {
    return DateFormatKind.ymd;
  }
  var dmy = 0, mdy = 0;
  for (final s in samples) {
    final m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.]').firstMatch(s.trim());
    if (m == null) continue;
    if (int.parse(m.group(1)!) > 12) {
      dmy++;
    } else if (int.parse(m.group(2)!) > 12) {
      mdy++;
    }
  }
  return mdy > dmy ? DateFormatKind.mdy : DateFormatKind.dmy;
}

class Mapping {
  Mapping({
    required this.date,
    required this.description,
    required this.amount,
    required this.debit,
    required this.credit,
    required this.dateFormat,
  });
  int date, description, amount, debit, credit;
  DateFormatKind dateFormat;
}

class ImportItem {
  const ImportItem(this.occurredOn, this.description, this.amount);
  final String occurredOn, description, amount;
}

String _cell(List<String> row, int index) => index >= 0 && index < row.length ? row[index].trim() : '';

/// Convierte filas de texto en movimientos con signo (positivo = ingreso, negativo = gasto).
({List<ImportItem> items, List<({int row, String reason})> errors}) buildItems(List<List<String>> rows, Mapping mapping, int firstDataRow) {
  final items = <ImportItem>[];
  final errors = <({int row, String reason})>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final rowNumber = firstDataRow + i;
    final date = parseCsvDate(_cell(row, mapping.date), mapping.dateFormat);
    if (date == null) {
      errors.add((row: rowNumber, reason: 'Fecha no válida'));
      continue;
    }
    double? amount;
    if (mapping.amount >= 0) {
      amount = parseCsvAmount(_cell(row, mapping.amount));
    } else {
      final debit = parseCsvAmount(_cell(row, mapping.debit));
      final credit = parseCsvAmount(_cell(row, mapping.credit));
      amount = (credit != null && credit != 0) ? credit.abs() : (debit != null ? -debit.abs() : null);
    }
    if (amount == null) {
      errors.add((row: rowNumber, reason: 'Monto no válido'));
      continue;
    }
    if (amount == 0) {
      errors.add((row: rowNumber, reason: 'El monto es cero'));
      continue;
    }
    final desc = _cell(row, mapping.description);
    items.add(ImportItem(date, desc.length > 255 ? desc.substring(0, 255) : desc, amount.toStringAsFixed(2)));
  }
  return (items: items, errors: errors);
}

/// ¿La primera fila parece un encabezado? (ninguna celda es fecha ni monto).
bool looksLikeHeader(List<String> row) => row.every(
  (c) => parseCsvAmount(c) == null && parseCsvDate(c, DateFormatKind.ymd) == null && parseCsvDate(c, DateFormatKind.dmy) == null,
);

final _names = {
  'date': RegExp(r'fecha|date', caseSensitive: false),
  'description': RegExp(r'descrip|concepto|detalle|memo|payee|narrat', caseSensitive: false),
  'amount': RegExp(r'monto|importe|valor|amount|^total$', caseSensitive: false),
  'debit': RegExp(r'd[eé]bito|debit|cargo|retiro', caseSensitive: false),
  'credit': RegExp(r'cr[eé]dito|credit|abono|dep[oó]sito', caseSensitive: false),
};

/// Propone un mapeo a partir de los nombres del encabezado (el usuario puede corregirlo).
Mapping guessMapping(List<String> header, DateFormatKind dateFormat) {
  int find(RegExp re) => header.indexWhere(re.hasMatch);
  final amount = find(_names['amount']!);
  return Mapping(
    date: find(_names['date']!),
    description: find(_names['description']!),
    amount: amount,
    debit: amount >= 0 ? -1 : find(_names['debit']!),
    credit: amount >= 0 ? -1 : find(_names['credit']!),
    dateFormat: dateFormat,
  );
}
