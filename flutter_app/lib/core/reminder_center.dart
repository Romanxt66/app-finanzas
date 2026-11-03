import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'format.dart';
import 'models.dart';
import 'reminder_scheduler.dart';
import 'reminders.dart';

/// Recordatorios de cobro: calcula los cobros próximos, los programa como avisos del sistema
/// (en Android) y guarda los ajustes. La hoja, el banner y los ajustes de la app leen de aquí.
class ReminderCenter extends ChangeNotifier {
  ReminderCenter(this._prefs, this._api, {ReminderScheduler? scheduler})
    : scheduler = scheduler ?? ReminderScheduler.platform(),
      settings = ReminderSettings.load(_prefs);

  final SharedPreferences _prefs;
  final ApiClient _api;
  final ReminderScheduler scheduler;

  ReminderSettings settings;

  /// Cobros de hoy a un mes (con los de hoy ya registrados, como pagados).
  List<Charge> charges = const [];
  List<Account> accounts = const [];
  double? hourlyRate;
  bool loaded = false;

  /// Permiso del sistema para mostrar avisos (null: no se sabe o no aplica).
  bool? permission;

  /// La raíz de la app navega a la ruta que pide un aviso tocado.
  void Function(String route)? onOpen;

  static const _registeredKey = 'reminders_registered';
  static const _askedKey = 'reminders_asked';
  static const _dismissedKey = 'reminders_dismissed';

  bool get supported => scheduler.supported;

  Future<void> init() async {
    if (!supported) return;
    try {
      await scheduler.init((route) => onOpen?.call(route));
      permission = await scheduler.permission();
    } catch (_) {
      // Sin avisos del sistema la app sigue igual (banner, hoja y campana)
    }
  }

  Future<String?> launchRoute() async {
    try {
      return await scheduler.launchRoute();
    } catch (_) {
      return null;
    }
  }

  Future<void>? _running;
  bool _again = false;

  /// Vuelve a calcular (y reprogramar). Las llamadas seguidas se agrupan.
  Future<void> refresh() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final run = () async {
      do {
        _again = false;
        await _load();
      } while (_again);
    }();
    _running = run.whenComplete(() => _running = null);
    return _running!;
  }

  /// Espera al primer cálculo (o al que esté en curso).
  Future<void> ensureLoaded() => _running ?? (loaded ? Future.value() : refresh());

  Future<double?> _hourlyRate() async {
    try {
      final j = await _api.get('/life-hours/profile') as Map<String, dynamic>;
      return money(j['hourly_rate']);
    } catch (_) {
      return null; // sin perfil de horas de vida
    }
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final r = await Future.wait<Object?>([
        _api.get('/recurring'),
        _api.get('/accounts', query: {'include_archived': true}),
        settings.subscriptions ? _api.get('/ghost-subscriptions', query: {'today': isoDate(now)}) : Future<Object?>.value(),
        _hourlyRate(),
      ]);
      final rules = [for (final j in r[0] as List) Recurring.fromJson(j as Map<String, dynamic>)];
      accounts = [for (final j in r[1] as List) Account.fromJson(j as Map<String, dynamic>)];
      final ghost = r[2] == null ? null : GhostReport.fromJson(r[2] as Map<String, dynamic>);
      hourlyRate = r[3] as double?;
      charges = withRegistered(
        projectCharges(rules: rules, accounts: accounts, subscriptions: ghost?.subscriptions ?? const [], today: now),
        _registered(now),
        rules: rules,
        accounts: accounts,
        today: now,
      );
      loaded = true;
      notifyListeners();
      await _sync();
    } catch (_) {
      // Es secundario: sin conexión se conservan el último cálculo y lo ya programado
    }
  }

  Future<void> _sync() async {
    if (!supported) return;
    final plan = planReminders(charges, settings, now: DateTime.now(), hourlyRate: hourlyRate);
    try {
      await scheduler.schedule(plan, hideAmounts: settings.hideAmounts);
      if (plan.isNotEmpty) await _askOnce();
    } catch (_) {}
  }

  /// La primera vez que hay algo que avisar, pide el permiso de avisos (Android 13+).
  Future<void> _askOnce() async {
    permission = await scheduler.permission();
    if (permission == true || _prefs.getBool(_askedKey) == true) return;
    await _prefs.setBool(_askedKey, true);
    permission = await scheduler.requestPermission();
    notifyListeners();
  }

  Future<void> update(ReminderSettings s) async {
    final old = settings;
    settings = s;
    await s.save(_prefs);
    notifyListeners();
    if (supported && s.enabled && !old.enabled && permission != true) await requestPermission();
    if (s.subscriptions != old.subscriptions) {
      await refresh();
    } else {
      await _sync();
    }
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      permission = await scheduler.requestPermission();
    } catch (_) {
      permission = false;
    }
    notifyListeners();
    return permission == true;
  }

  Future<void> openSystemSettings() => scheduler.openSystemSettings();

  /// El aviso de ejemplo: el próximo de verdad o, si no hay, uno de muestra.
  PlannedReminder previewReminder() {
    final now = DateTime.now();
    final next = planReminders(
      charges,
      settings.copyWith(enabled: true),
      now: now,
      hourlyRate: hourlyRate,
    ).where((r) => r.charge != null).firstOrNull;
    if (next != null) return next;
    final c = sampleCharge(now);
    final day = c.date.subtract(const Duration(days: 1));
    return PlannedReminder(
      id: 1,
      at: now,
      title: chargeTitle(c, day),
      body: chargeBody(c, day, hourlyRate: hourlyRate),
      route: chargesRoute(c.date),
      charge: c,
      ticket: ticketFor(c, day),
    );
  }

  /// «Probar un aviso». Devuelve false si no hay permiso.
  Future<bool> showTest() async {
    if (!supported) return false;
    if (await scheduler.permission() != true && !await requestPermission()) return false;
    final r = previewReminder();
    await scheduler.show(
      PlannedReminder(
        id: 1,
        at: DateTime.now(),
        title: r.title,
        body: r.body,
        route: r.route,
        charge: r.charge,
        ticket: r.ticket,
        moveRoute: r.moveRoute,
      ),
      hideAmounts: settings.hideAmounts,
    );
    return true;
  }

  /// «Recordar a las 6 p. m.» desde la hoja de cobros del día.
  Future<bool> remindAt(DateTime day, DateTime at) async {
    final list = chargesOn(charges, day).where((c) => !c.paid).toList();
    if (!supported || list.isEmpty || !at.isAfter(DateTime.now())) return false;
    if (await scheduler.permission() != true && !await requestPermission()) return false;
    final first = list.first;
    final one = list.length == 1;
    await scheduler.show(
      PlannedReminder(
        id: 2,
        at: at,
        title: one ? chargeTitle(first, at) : 'Hoy se cobran ${list.length} pagos',
        body: one ? chargeBody(first, at, hourlyRate: hourlyRate) : '${totalsText(list)} en total. Toca para verlos.',
        route: chargesRoute(day),
        charge: one ? first : null,
        ticket: one ? ticketFor(first, at) : null,
        moveRoute: one && first.short && first.accountId != null ? moveMoneyRoute(first) : null,
      ),
      hideAmounts: settings.hideAmounts,
      later: true,
    );
    return true;
  }

  // ─── Cobros registrados hoy ───────────────────────────────────────────────────────────────

  List<Charge> _registered(DateTime now) {
    final raw = _prefs.getString(_registeredKey);
    if (raw == null) return const [];
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['date'] != isoDate(now)) return const [];
      return [for (final c in j['items'] as List) Charge.fromJson(c as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  /// Cobros recurrentes de hoy pendientes de registrar (justo antes de ejecutar los recurrentes).
  Future<List<Charge>> dueToday() async {
    await ensureLoaded();
    return chargesOn(charges, DateTime.now()).where((c) => !c.paid && !c.detected).toList();
  }

  /// Tras registrar los recurrentes vencidos: hoy se mostrarán como pagados.
  Future<void> markRegistered(List<Charge> due) async {
    if (due.isEmpty) return;
    final now = DateTime.now();
    final byKey = {
      for (final c in [..._registered(now), ...due]) c.key: c,
    };
    await _prefs.setString(
      _registeredKey,
      jsonEncode({
        'date': isoDate(now),
        'items': [for (final c in byKey.values) c.toJson()],
      }),
    );
  }

  // ─── Banner «no alcanza» ──────────────────────────────────────────────────────────────────

  Set<String> _dismissed() {
    final raw = _prefs.getStringList(_dismissedKey) ?? const [];
    final today = isoDate(DateTime.now());
    return {
      for (final e in raw)
        if (e.startsWith('$today|')) e.substring(today.length + 1),
    };
  }

  /// Cobro de hoy o mañana que no alcanza (si no se descartó hoy).
  Charge? get alert {
    final c = alertCharge(charges, DateTime.now());
    return c == null || _dismissed().contains(c.key) ? null : c;
  }

  Future<void> dismiss(Charge c) async {
    final today = isoDate(DateTime.now());
    await _prefs.setStringList(_dismissedKey, [
      for (final k in {..._dismissed(), c.key}) '$today|$k',
    ]);
    notifyListeners();
  }

  /// Al cerrar sesión: nada de esta cuenta queda en el teléfono.
  Future<void> clear() async {
    charges = const [];
    accounts = const [];
    hourlyRate = null;
    loaded = false;
    await _prefs.remove(_registeredKey);
    await _prefs.remove(_dismissedKey);
    notifyListeners();
    if (supported) {
      try {
        await scheduler.cancelAll();
      } catch (_) {}
    }
  }
}
