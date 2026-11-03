import 'dart:async';

import 'package:flutter/rendering.dart';

import '../screens/insights.dart' show financeMood;
import '../ui/charge_ticket.dart' show paintToPng;
import '../ui/home_widgets.dart';
import 'data.dart';
import 'format.dart';
import 'models.dart';
import 'native_app.dart';
import 'reminders.dart';
import 'state.dart';
import 'widget_files_stub.dart' if (dart.library.io) 'widget_files_io.dart';

/// Frase corta de Alvi para el widget de saldo (la del resumen no cabe).
const _moodLines = [
  'Tu dinero necesita un respiro.',
  'El mes se está apretando.',
  'Todo en orden, sin sobresaltos.',
  'Vas muy bien este mes.',
  '¡Tus finanzas brillan!',
];

/// Datos de los widgets a partir de lo que ya muestra la app (todo formateado).
HomeWidgetData buildWidgetData({
  required List<Account> accounts,
  required Summary? summary,
  DailyAllowance? allowance,
  List<Budget> budgets = const [],
  List<Goal> goals = const [],
  List<Charge> charges = const [],
  required DateTime now,
}) {
  final active = accounts.where((a) => !a.archived).toList();
  final currency = summary?.currency ?? active.firstOrNull?.currency;
  final total = active.where((a) => currency == null || a.currency == currency).fold<double>(0, (t, a) => t + a.balance);
  final income = summary?.income ?? 0;
  final expense = summary?.expense ?? 0;
  final mood = financeMood(income: income, expense: expense, balance: total, allowanceStatus: allowance?.status, budgets: budgets);
  final line = _moodLines[mood.level];

  String? todayLeft;
  var fraction = 0.0;
  var over = false;
  var level = 2;
  if (allowance != null) {
    over = allowance.leftToday < 0;
    todayLeft = formatMoney(allowance.leftToday, allowance.currency);
    fraction = allowance.allowanceToday <= 0 ? 0 : allowance.leftToday / allowance.allowanceToday;
    level = over ? 1 : (fraction >= 0.5 ? 3 : 2);
  }

  final upcoming = charges.where((c) => !c.paid && daysBetween(now, c.date) >= 0).take(3);
  final goal = goals.where((g) => !g.achieved).firstOrNull ?? goals.firstOrNull;

  return HomeWidgetData(
    balance: formatMoney(total, currency),
    income: formatMoney(income, currency),
    expense: formatMoney(expense, currency),
    mood: mood.level,
    moodLine: line,
    todayLeft: todayLeft,
    todayLabel: over ? 'te pasaste hoy' : 'disponible hoy',
    todayFraction: fraction,
    todayOver: over,
    todayLevel: level,
    charges: [
      for (final c in upcoming)
        (
          name: c.name,
          when: c.short
              ? '${whenWord(c.date, now)} · no alcanza'
              : '${whenWord(c.date, now)}${c.accountName == null ? '' : ' · ${c.accountName!.toLowerCase()}'}',
          amount: formatMoney(c.amount, c.currency.isEmpty ? null : c.currency),
          short: c.short,
        ),
    ],
    goal: goal == null
        ? null
        : (
            name: goal.name,
            progress: goal.target <= 0 ? 0 : goal.saved / goal.target,
            left: formatMoney(goal.remaining, goal.currency),
            achieved: goal.achieved,
          ),
  );
}

/// Mantiene al día las imágenes de los widgets: al abrir la app, tras cada cambio y al cambiar el acento.
class WidgetSync {
  WidgetSync(this.app);
  final AppState app;
  Timer? _timer;

  /// Programa una actualización (las seguidas se agrupan).
  void schedule() {
    if (!NativeApp.supported) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () => unawaited(refresh()));
  }

  Future<void> refresh() async {
    if (app.user == null || await NativeApp.widgetCount() == 0) return;
    try {
      final data = app.data;
      final now = DateTime.now();
      final month = monthStart(now);
      final accounts = await data.accounts();
      final currency = accounts.where((a) => !a.archived).firstOrNull?.currency;
      final r = await Future.wait<Object?>([
        data.summary(month, currency),
        data.allowance().catchError((Object _) => null),
        data.budgets(month).catchError((Object _) => <Budget>[]),
        data.goals().catchError((Object _) => <Goal>[]),
      ]);
      await app.reminders.ensureLoaded();
      final d = buildWidgetData(
        accounts: accounts,
        summary: r[0] as Summary?,
        allowance: r[1] as DailyAllowance?,
        budgets: r[2] as List<Budget>,
        goals: r[3] as List<Goal>,
        charges: app.reminders.charges,
        now: now,
      );
      final tint = WidgetTint(app.accent);
      for (final kind in HomeWidgetKind.values) {
        await _write(kind.name, HomeWidgetPainter(kind, d, tint), kind.size);
      }
      await _write('balance_hidden', HomeWidgetPainter(HomeWidgetKind.balance, d, tint, hidden: true), HomeWidgetKind.balance.size);
      await NativeApp.updateWidgets();
    } catch (_) {
      // Sin conexión los widgets conservan la última imagen
    }
  }

  Future<void> _write(String name, CustomPainter painter, Size size) async {
    const scale = 3.0;
    await writeWidgetImage(name, await paintToPng(painter, size * scale));
  }
}
