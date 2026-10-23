import 'package:intl/intl.dart';

const _symbols = {
  'COP': r'$',
  'USD': r'US$',
  'EUR': '€',
  'GBP': '£',
  'JPY': 'JP¥',
  'CNY': 'CN¥',
  'MXN': r'MX$',
  'CAD': r'CA$',
  'AUD': r'AU$',
  'NZD': r'NZ$',
  'BRL': r'R$',
  'ARS': r'AR$',
  'CLP': r'CLP',
  'INR': '₹',
  'KRW': '₩',
};

const currencyNames = {
  'USD': 'Dólar estadounidense',
  'EUR': 'Euro',
  'GBP': 'Libra esterlina',
  'JPY': 'Yen japonés',
  'CNY': 'Yuan chino',
  'CHF': 'Franco suizo',
  'CAD': 'Dólar canadiense',
  'AUD': 'Dólar australiano',
  'NZD': 'Dólar neozelandés',
  'MXN': 'Peso mexicano',
  'BRL': 'Real brasileño',
  'ARS': 'Peso argentino',
  'CLP': 'Peso chileno',
  'COP': 'Peso colombiano',
  'PEN': 'Sol peruano',
  'UYU': 'Peso uruguayo',
  'BOB': 'Boliviano',
  'PYG': 'Guaraní paraguayo',
  'VES': 'Bolívar venezolano',
  'DOP': 'Peso dominicano',
  'CRC': 'Colón costarricense',
  'GTQ': 'Quetzal guatemalteco',
  'INR': 'Rupia india',
  'KRW': 'Won surcoreano',
  'SEK': 'Corona sueca',
  'NOK': 'Corona noruega',
  'DKK': 'Corona danesa',
  'PLN': 'Esloti polaco',
};

String currencyLabel(String code) => currencyNames.containsKey(code) ? '$code · ${currencyNames[code]}' : code;

int _decimals(String? currency) => (currency == 'COP' || currency == 'CLP' || currency == 'JPY' || currency == 'KRW') ? 0 : 2;

/// Monto con signo tipográfico (−). [signed] añade «+» a los positivos. Sin moneda: solo el número.
String formatMoney(num value, [String? currency, bool signed = false]) {
  final n = value.toDouble();
  final fmt = NumberFormat.decimalPatternDigits(
    locale: 'es_CO',
    decimalDigits: currency == null ? (n == n.roundToDouble() ? 0 : 2) : _decimals(currency),
  );
  final body = fmt.format(n.abs());
  final abs = currency == null ? body : '${_symbols[currency] ?? currency} $body';
  if (n < 0 && n.abs() >= 0.005) return '− $abs';
  return signed && n > 0 ? '+ $abs' : abs;
}

/// 18.2 → «18,2» (hasta un decimal).
String formatPercent(num value) => NumberFormat('#,##0.#', 'es_CO').format(value);

String formatCompact(num value) => NumberFormat.compact(locale: 'es_CO').format(value);

DateTime parseIso(String iso) => DateTime.parse('${iso.substring(0, 10)}T00:00:00');

/// «8 de oct».
String formatDate(String iso) {
  final d = parseIso(iso);
  final m = DateFormat.MMM('es').format(d).replaceAll('.', '');
  return '${d.day} de $m';
}

String monthStart([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-01';
}

String todayISO() => DateFormat('yyyy-MM-dd').format(DateTime.now());

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Abreviatura corta del mes («oct.»).
String monthLabel(String iso) => '${DateFormat.MMM('es').format(parseIso(iso))}.';

/// 0,2 → «12 min»; 1,5 → «1 h 30 min»; 26 → «26 h».
String formatHours(double hours) {
  final minutes = (hours * 60).round();
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return (m == 0 || h >= 10) ? '$h h' : '$h h $m min';
}

/// Valor de la hora a partir del ingreso neto mensual y las horas semanales.
double? hourlyRate(double monthlyNetIncome, double weeklyHours) {
  final perMonth = weeklyHours * 52 / 12;
  return monthlyNetIncome > 0 && perMonth > 0 ? monthlyNetIncome / perMonth : null;
}

/// Texto para junto a un gasto («≈ 1 h 12 min de trabajo»).
String? lifeHoursNote(double amount, double? rate) {
  if (rate == null || rate <= 0) return null;
  return '≈ ${formatHours(amount.abs() / rate)} de trabajo';
}

final _amountRe = RegExp(r'^\d+(\.\d{1,2})?$');

/// Valida montos como la web (`^\d+(\.\d{1,2})?$`) y normaliza la coma decimal.
String? parseAmount(String raw, {bool allowNegative = false}) {
  var s = raw.trim().replaceAll(RegExp(r'[\s$]'), '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  final neg = allowNegative && s.startsWith('-');
  final body = neg ? s.substring(1) : s;
  return _amountRe.hasMatch(body) ? s : null;
}

const amountError = 'Monto positivo con hasta 2 decimales';

/// Cuánto ahorrar al mes para llegar a la fecha límite (null si no aplica).
double? monthlyNeeded({required DateTime? deadline, required double remaining, required bool achieved, DateTime? now}) {
  if (deadline == null || achieved) return null;
  final n = now ?? DateTime.now();
  final months = (deadline.year - n.year) * 12 + (deadline.month - n.month);
  return months <= 0 ? null : remaining / months;
}
