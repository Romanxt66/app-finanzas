import 'package:intl/intl.dart';

final _number = NumberFormat.decimalPatternDigits(
  locale: 'es_CO',
  decimalDigits: 0,
);
final _numberDec = NumberFormat.decimalPatternDigits(
  locale: 'es_CO',
  decimalDigits: 2,
);

/// "$ 12.480.500" (sin decimales si es entero).
String fmtMoney(double v, {String? currency, bool sign = false}) {
  final abs = v.abs();
  final body = abs == abs.roundToDouble()
      ? _number.format(abs)
      : _numberDec.format(abs);
  final prefix = v < 0 ? '− ' : (sign && v > 0 ? '+ ' : '');
  return '$prefix\$ $body${currency == null ? '' : ' $currency'}';
}

String fmtDate(DateTime d) => DateFormat("d 'de' MMM", 'es').format(d);
String fmtMonth(DateTime d) {
  final s = DateFormat("MMMM 'de' y", 'es').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month);

/// Acepta "1.234,56", "1234.56" o "1234,56" y devuelve una cadena decimal para la API.
String? parseAmount(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[\s$]'), '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s) ? s : null;
}
