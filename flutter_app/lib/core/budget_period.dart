import 'package:intl/intl.dart';

import 'format.dart';

// Periodos de los presupuestos: día, semana (de lunes a domingo) o mes.

const budgetPeriods = [('day', 'Día'), ('week', 'Semana'), ('month', 'Mes')];

/// «cada día», «cada semana», «cada mes».
const budgetEvery = {'day': 'cada día', 'week': 'cada semana', 'month': 'cada mes'};

/// «hoy», «esta semana», «este mes».
const budgetNow = {'day': 'hoy', 'week': 'esta semana', 'month': 'este mes'};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Primer día del periodo que contiene [d].
DateTime periodStart(String period, DateTime d) => switch (period) {
  'month' => DateTime(d.year, d.month),
  'week' => _day(d).subtract(Duration(days: d.weekday - 1)),
  _ => _day(d),
};

/// El periodo anterior (−1) o siguiente (+1).
DateTime shiftPeriod(String period, DateTime d, int by) {
  final s = periodStart(period, d);
  return switch (period) {
    'month' => DateTime(s.year, s.month + by),
    'week' => DateTime(s.year, s.month, s.day + 7 * by),
    _ => DateTime(s.year, s.month, s.day + by),
  };
}

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];

/// «mar 11 nov», «10 – 16 nov», «noviembre 2026».
String periodLabel(String period, DateTime d) {
  final s = periodStart(period, d);
  if (period == 'month') return DateFormat('MMMM y', 'es').format(s);
  if (period == 'day') return '${DateFormat('EEE', 'es').format(s).replaceAll('.', '')} ${s.day} ${_months[s.month - 1]}';
  final e = s.add(const Duration(days: 6));
  return s.month == e.month
      ? '${s.day} – ${e.day} ${_months[e.month - 1]}'
      : '${s.day} ${_months[s.month - 1]} – ${e.day} ${_months[e.month - 1]}';
}

String periodIso(String period, DateTime d) => isoDate(periodStart(period, d));
