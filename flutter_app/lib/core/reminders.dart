import 'dart:convert';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'models.dart';

// Recordatorios de cobro: qué se cobra en los próximos días (gastos recurrentes y suscripciones
// detectadas), cuánto quedaría en cada cuenta y qué avisos programar. Todo aquí es lógica pura:
// la programación en el sistema vive en reminder_scheduler*.dart y la vista en screens/reminders.dart.

/// Cuándo avisar de un cobro.
enum ReminderWhen {
  dayBefore('El día antes'),
  sameDay('El mismo día'),
  both('Ambos');

  const ReminderWhen(this.label);
  final String label;
}

/// Ajustes de los recordatorios de cobro (de este dispositivo).
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.when = ReminderWhen.both,
    this.hour = 9,
    this.recurring = true,
    this.subscriptions = true,
    this.hideAmounts = false,
  });

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
    enabled: j['enabled'] != false,
    when: ReminderWhen.values.where((w) => w.name == j['when']).firstOrNull ?? ReminderWhen.both,
    hour: hours.contains(j['hour']) ? j['hour'] as int : 9,
    recurring: j['recurring'] != false,
    subscriptions: j['subscriptions'] != false,
    hideAmounts: j['hide_amounts'] == true,
  );

  final bool enabled;
  final ReminderWhen when;

  /// Hora del aviso (una de [hours]).
  final int hour;

  /// Avisar de los pagos recurrentes.
  final bool recurring;

  /// Avisar de las suscripciones detectadas que no están en los recurrentes.
  final bool subscriptions;

  /// Ocultar el contenido del aviso en la pantalla de bloqueo.
  final bool hideAmounts;

  static const hours = [8, 9, 18];
  static const _key = 'reminder_settings';

  bool get dayBefore => when != ReminderWhen.sameDay;
  bool get sameDay => when != ReminderWhen.dayBefore;

  ReminderSettings copyWith({bool? enabled, ReminderWhen? when, int? hour, bool? recurring, bool? subscriptions, bool? hideAmounts}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        when: when ?? this.when,
        hour: hour ?? this.hour,
        recurring: recurring ?? this.recurring,
        subscriptions: subscriptions ?? this.subscriptions,
        hideAmounts: hideAmounts ?? this.hideAmounts,
      );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'when': when.name,
    'hour': hour,
    'recurring': recurring,
    'subscriptions': subscriptions,
    'hide_amounts': hideAmounts,
  };

  static ReminderSettings load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const ReminderSettings();
    try {
      return ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReminderSettings();
    }
  }

  Future<void> save(SharedPreferences prefs) => prefs.setString(_key, jsonEncode(toJson()));

  @override
  bool operator ==(Object other) => other is ReminderSettings && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// 8 → «8 a. m.»; 18 → «6 p. m.».
String hourLabel(int hour) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h ${hour < 12 ? 'a. m.' : 'p. m.'}';
}

const frequencyWords = {'weekly': 'cada semana', 'monthly': 'cada mes', 'yearly': 'cada año'};

// ─── Cobros ─────────────────────────────────────────────────────────────────────────────────────

enum ChargeSource { recurring, subscription }

/// Cómo queda un cobro frente al saldo de su cuenta.
enum ChargeStatus {
  /// Alcanza: queda saldo después del cobro.
  covered,

  /// No alcanza: la cuenta quedaría (o quedó) en negativo.
  short,

  /// Ya se registró hoy y la cuenta sigue en positivo.
  paid,

  /// Sin cuenta conocida (suscripción detectada o tarjeta de crédito): no se juzga.
  unknown,
}

/// Un cobro previsto (o registrado hoy).
class Charge {
  const Charge({
    required this.key,
    required this.source,
    required this.name,
    required this.amount,
    required this.currency,
    required this.date,
    required this.frequency,
    this.ruleId,
    this.accountId,
    this.accountName,
    this.remaining,
    this.paid = false,
    this.nextDate,
  });

  factory Charge.fromJson(Map<String, dynamic> j) => Charge(
    key: j['key'] as String,
    source: j['source'] == 'subscription' ? ChargeSource.subscription : ChargeSource.recurring,
    name: j['name'] as String,
    amount: (j['amount'] as num).toDouble(),
    currency: j['currency'] as String,
    date: parseIso(j['date'] as String),
    frequency: j['frequency'] as String,
    ruleId: j['rule_id'] as String?,
    accountId: j['account_id'] as String?,
    accountName: j['account_name'] as String?,
  );

  /// Identifica el cobro: regla (o nombre de la suscripción) y fecha.
  final String key;
  final ChargeSource source;
  final String name;
  final double amount;
  final String currency;

  /// Día del cobro (sin hora).
  final DateTime date;

  /// weekly, monthly o yearly.
  final String frequency;
  final String? ruleId, accountId, accountName;

  /// Lo que queda en la cuenta después del cobro; null si no se sabe.
  final double? remaining;

  /// Ya se registró como movimiento (hoy).
  final bool paid;

  /// Cobro siguiente a este (para «pagado»).
  final DateTime? nextDate;

  ChargeStatus get status {
    if (remaining != null && remaining! < 0) return ChargeStatus.short;
    if (paid) return ChargeStatus.paid;
    return remaining == null ? ChargeStatus.unknown : ChargeStatus.covered;
  }

  bool get short => status == ChargeStatus.short;

  /// Lo que falta para cubrirlo (0 si alcanza).
  double get shortfall => remaining != null && remaining! < 0 ? -remaining! : 0;

  bool get detected => source == ChargeSource.subscription;

  Charge copyWith({double? remaining, bool clearRemaining = false, bool? paid, DateTime? nextDate, DateTime? date}) => Charge(
    key: key,
    source: source,
    name: name,
    amount: amount,
    currency: currency,
    date: date ?? this.date,
    frequency: frequency,
    ruleId: ruleId,
    accountId: accountId,
    accountName: accountName,
    remaining: clearRemaining ? null : (remaining ?? this.remaining),
    paid: paid ?? this.paid,
    nextDate: nextDate ?? this.nextDate,
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'source': source.name,
    'name': name,
    'amount': amount,
    'currency': currency,
    'date': isoDate(date),
    'frequency': frequency,
    'rule_id': ruleId,
    'account_id': accountId,
    'account_name': accountName,
  };
}

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Días de calendario entre dos fechas (sin que el cambio de hora reste un día).
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

int _lastDay(int year, int month) => DateTime(year, month + 1, 0).day;

/// Siguiente ocurrencia de una regla, como en el servidor: los meses cortos recortan el día sin perder el ancla.
DateTime nextOccurrence(DateTime d, String frequency, int anchorDay) {
  switch (frequency) {
    case 'weekly':
      return _addDays(d, 7);
    case 'monthly':
      final year = d.month == 12 ? d.year + 1 : d.year;
      final month = d.month == 12 ? 1 : d.month + 1;
      return DateTime(year, month, math.min(anchorDay, _lastDay(year, month)));
    default:
      return DateTime(d.year + 1, d.month, math.min(anchorDay, _lastDay(d.year + 1, d.month)));
  }
}

/// Las tarjetas de crédito llevan saldo de deuda: no se puede decir si «alcanza».
bool _judgeable(Account? a) => a != null && a.type != 'card';

class _Flow {
  _Flow(this.date, this.amount, [this.charge]);
  final DateTime date;

  /// Con signo: entra (+) o sale (−).
  final double amount;
  final Charge? charge;
}

/// Cobros de hoy a [horizonDays] días: gastos recurrentes activos y suscripciones detectadas sin registrar,
/// con lo que quedaría en cada cuenta después de cada uno (sumando también los ingresos y transferencias
/// recurrentes previstos). Los vencidos que aún no se registraron cuentan como de hoy.
List<Charge> projectCharges({
  required List<Recurring> rules,
  required List<Account> accounts,
  List<Subscription> subscriptions = const [],
  required DateTime today,
  int horizonDays = 31,
}) {
  final start = dayOf(today);
  final end = _addDays(start, horizonDays);
  final byId = {for (final a in accounts) a.id: a};
  final flows = <String, List<_Flow>>{};
  void add(String accountId, _Flow f) => (flows[accountId] ??= []).add(f);

  for (final r in rules) {
    if (!r.active || r.amount <= 0) continue;
    final last = r.endDate == null ? null : parseIso(r.endDate!);
    var d = parseIso(r.nextDate);
    final anchor = d.day;
    for (var guard = 0; !d.isAfter(end) && (last == null || !d.isAfter(last)) && guard < 60; guard++) {
      final on = d.isBefore(start) ? start : d;
      switch (r.type) {
        case 'expense':
          final account = byId[r.accountId];
          add(
            r.accountId,
            _Flow(
              on,
              -r.amount,
              Charge(
                key: 'r:${r.id}:${isoDate(d)}',
                source: ChargeSource.recurring,
                name: r.description.trim().isEmpty ? 'Pago recurrente' : r.description.trim(),
                amount: r.amount,
                currency: account?.currency ?? '',
                date: on,
                frequency: r.frequency,
                ruleId: r.id,
                accountId: r.accountId,
                accountName: account?.name,
              ),
            ),
          );
        case 'income':
          add(r.accountId, _Flow(on, r.amount));
        case 'transfer':
          add(r.accountId, _Flow(on, -r.amount));
          if (r.transferAccountId != null) add(r.transferAccountId!, _Flow(on, r.amount));
      }
      d = nextOccurrence(d, r.frequency, anchor);
    }
  }

  final out = <Charge>[];
  for (final MapEntry(key: accountId, value: list) in flows.entries) {
    // El mismo día entra primero lo que suma y luego salen los cobros de menor a mayor
    list.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      if ((a.amount > 0) != (b.amount > 0)) return a.amount > 0 ? -1 : 1;
      return b.amount.compareTo(a.amount);
    });
    final account = byId[accountId];
    var balance = account?.balance ?? 0;
    for (final f in list) {
      balance += f.amount;
      final charge = f.charge;
      if (charge == null) continue;
      out.add(_judgeable(account) ? charge.copyWith(remaining: balance) : charge);
    }
  }

  for (final s in subscriptions) {
    if (s.tracked || s.lastAmount <= 0) continue;
    final d = parseIso(s.nextExpected);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    out.add(
      Charge(
        key: 's:${s.name}:${s.nextExpected}',
        source: ChargeSource.subscription,
        name: s.name,
        amount: s.lastAmount,
        currency: s.currency,
        date: d,
        frequency: s.cadence,
      ),
    );
  }
  out.sort(_byDateThenAmount);
  return out;
}

int _byDateThenAmount(Charge a, Charge b) {
  final byDate = a.date.compareTo(b.date);
  return byDate != 0 ? byDate : b.amount.compareTo(a.amount);
}

/// Añade los cobros de hoy que ya se registraron (guardados justo antes de ejecutar los recurrentes):
/// quedan como pagados, con el saldo actual de su cuenta y su próximo cobro.
List<Charge> withRegistered(
  List<Charge> projected,
  List<Charge> registered, {
  required List<Recurring> rules,
  required List<Account> accounts,
  required DateTime today,
}) {
  final day = dayOf(today);
  final keys = {for (final c in projected) c.key};
  final paid = <Charge>[];
  for (final r in registered) {
    if (daysBetween(r.date, day) != 0 || keys.contains(r.key)) continue;
    final rule = rules.where((x) => x.id == r.ruleId).firstOrNull;
    final account = accounts.where((a) => a.id == r.accountId).firstOrNull;
    paid.add(
      r.copyWith(
        paid: true,
        remaining: _judgeable(account) ? account!.balance : null,
        clearRemaining: !_judgeable(account),
        nextDate: rule == null || !rule.active ? null : parseIso(rule.nextDate),
      ),
    );
  }
  return [...projected, ...paid]..sort(_byDateThenAmount);
}

/// Cobros de un día concreto.
List<Charge> chargesOn(List<Charge> charges, DateTime day) => charges.where((c) => daysBetween(c.date, day) == 0).toList();

/// El cobro que no alcanza más cercano (hoy o mañana), para el banner de la app.
Charge? alertCharge(List<Charge> charges, DateTime today) =>
    charges.where((c) => c.short && daysBetween(today, c.date) >= 0 && daysBetween(today, c.date) <= 1).firstOrNull;

/// Cuenta desde la que cubrir lo que falta: misma moneda, con saldo suficiente (la de más saldo).
Account? suggestSource(Charge charge, List<Account> accounts) {
  final options =
      accounts.where((a) => !a.archived && a.type != 'card' && a.id != charge.accountId && a.currency == charge.currency).toList()
        ..sort((a, b) => b.balance.compareTo(a.balance));
  final best = options.firstOrNull;
  return best != null && best.balance >= charge.shortfall ? best : null;
}

/// Ruta del formulario de transferencia precargado para cubrir un cobro.
String moveMoneyRoute(Charge charge, {Account? from}) => Uri(
  path: '/transactions',
  queryParameters: {
    'mover': charge.accountId ?? '',
    'desde': ?from?.id,
    'monto': _plainAmount(charge.shortfall),
    'nota': 'Para cubrir ${charge.name}',
  },
).toString();

/// Ruta de la hoja de cobros de un día.
String chargesRoute(DateTime day) => '/?cobros=${isoDate(day)}';

String _plainAmount(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

// ─── Textos ─────────────────────────────────────────────────────────────────────────────────────

/// «hoy», «mañana» o «el sábado».
String whenWord(DateTime date, DateTime today) {
  final days = daysBetween(today, date);
  if (days == 0) return 'hoy';
  if (days == 1) return 'mañana';
  return 'el ${DateFormat.EEEE('es').format(date)}';
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Título del aviso de un cobro (`on` = día en que se muestra).
String chargeTitle(Charge c, DateTime on) {
  final when = whenWord(c.date, on);
  return c.short ? '${_cap(when)} se cobra ${c.name} y no alcanza' : '${_cap(when)} se cobra ${c.name}';
}

/// Cuerpo del aviso de un cobro.
String chargeBody(Charge c, DateTime on, {double? hourlyRate}) {
  final amount = formatMoneyCode(c.amount, c.currency);
  final from = c.accountName == null ? '' : ' de ${c.accountName}';
  switch (c.status) {
    case ChargeStatus.short:
      final soon = daysBetween(on, c.date) == 0 ? 'Mueve dinero antes de que se cobre.' : 'Aún tienes tiempo de mover dinero.';
      return 'Faltan ${formatMoneyCode(c.shortfall, c.currency)} en ${c.accountName ?? 'la cuenta'} para cubrir $amount. $soon';
    case ChargeStatus.covered:
      final hours = hourlyRate == null || hourlyRate <= 0 ? '' : ' Equivale a unas ${formatHours(c.amount / hourlyRate)} de tu trabajo.';
      return '$amount$from. Te quedarán ${formatMoneyCode(c.remaining!, c.currency)}.$hours';
    case ChargeStatus.paid:
      return '$amount$from. Ya quedó registrado.';
    case ChargeStatus.unknown:
      return c.detected ? '$amount · suscripción detectada en tus movimientos.' : '$amount$from.';
  }
}

/// Encabezado mono de la hoja: «lunes 16 nov · 2 cobros · $ 1.194.900».
String dayHeading(DateTime day, List<Charge> charges) {
  final date = '${DateFormat.EEEE('es').format(day)} ${day.day} ${DateFormat.MMM('es').format(day).replaceAll('.', '')}';
  if (charges.isEmpty) return '$date · sin cobros';
  final n = charges.length == 1 ? '1 cobro' : '${charges.length} cobros';
  return '$date · $n · ${totalsText(charges)}';
}

/// Suma por moneda: «$ 1.194.900» o «$ 50.000 + € 12,99».
String totalsText(List<Charge> charges) {
  final totals = <String, double>{};
  for (final c in charges) {
    totals[c.currency] = (totals[c.currency] ?? 0) + c.amount;
  }
  return totals.entries.map((e) => formatMoney(e.value, e.key.isEmpty ? null : e.key)).join(' + ');
}

String _names(List<Charge> list) {
  final names = list.map((c) => c.name).toList();
  if (names.length <= 1) return names.join();
  return '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
}

/// Lo que dice Alvi en la hoja de cobros del día.
String alviLine(List<Charge> charges, List<Account> accounts, {required bool isToday}) {
  if (charges.isEmpty) return isToday ? 'Hoy no se cobra nada. ¡Día tranquilo!' : 'Ese día no hay cobros previstos.';
  final short = charges.where((c) => c.short).toList();
  final paid = charges.where((c) => c.status == ChargeStatus.paid).toList();
  final fine = charges.where((c) => c.status == ChargeStatus.covered).toList();
  if (short.isNotEmpty) {
    final s = short.first;
    final lead = fine.isEmpty ? '' : '${_names(fine)} ${fine.length == 1 ? 'está cubierto' : 'están cubiertos'}, pero ';
    final source = suggestSource(s, accounts);
    final ask = source == null ? ' Mueve dinero antes de que se cobre.' : ' ¿Los pasamos desde ${source.name}?';
    return '${_cap(lead)}${lead.isEmpty ? 'P' : 'p'}ara ${s.name} faltan ${formatMoney(s.shortfall, s.currency)}.$ask';
  }
  if (paid.isNotEmpty && fine.isEmpty) {
    return 'Ya registré ${_names(paid)}. Todo en orden.';
  }
  if (fine.isNotEmpty) {
    return charges.length == 1 ? '${charges.first.name} está cubierto. Todo en orden.' : 'Todo está cubierto. Todo en orden.';
  }
  return 'Te cuento lo que se cobra para que no te pille por sorpresa.';
}

// ─── Tarjeta de cobro (imagen del aviso y vista previa) ─────────────────────────────────────────

enum TicketVariant { covered, short, paid }

enum ChipTone { good, bad, neutral }

/// Textos de la tarjeta de cobro; los colores salen de [variant].
class TicketData {
  const TicketData({
    required this.variant,
    required this.merchant,
    required this.meta,
    required this.lead,
    required this.accent,
    required this.amount,
    required this.currency,
    required this.chip,
    required this.chipTone,
    required this.weekday,
    required this.day,
    required this.month,
  });

  final TicketVariant variant;
  final String merchant, meta, lead, accent, amount, currency, chip, weekday, day, month;
  final ChipTone chipTone;

  String get initial => merchant.isEmpty ? '·' : String.fromCharCode(merchant.runes.first).toUpperCase();

  /// Firma del contenido: misma firma, misma imagen (se reutiliza el archivo ya generado).
  String get signature =>
      [variant.name, merchant, meta, lead, accent, amount, currency, chip, chipTone.name, weekday, day, month].join('|');
}

/// Tarjeta de un cobro tal como se ve el día [on].
TicketData ticketFor(Charge c, DateTime on) {
  final status = c.status;
  final days = daysBetween(on, c.date);
  final when = whenWord(c.date, on);
  final variant = switch (status) {
    ChargeStatus.short => TicketVariant.short,
    ChargeStatus.paid => TicketVariant.paid,
    _ => TicketVariant.covered,
  };
  final where = c.detected ? 'suscripción' : (c.accountName ?? 'pago recurrente').toLowerCase();
  final month = DateFormat.MMM('es').format(c.date).replaceAll('.', '');
  final (lead, accent) = switch (status) {
    ChargeStatus.short => ('${_cap(when)} se cobra', 'y no alcanza'),
    ChargeStatus.paid => ('Listo,', 'registrado'),
    _ => ('Se cobra', when),
  };
  final (chip, tone) = switch (status) {
    ChargeStatus.short => ('te faltan ${formatMoney(c.shortfall, c.currency)}', ChipTone.bad),
    ChargeStatus.covered => ('te quedarán ${formatMoney(c.remaining!, c.currency)}', ChipTone.good),
    ChargeStatus.paid => (
      c.nextDate == null
          ? 'registrado hoy'
          : 'próximo cobro: ${c.nextDate!.day} ${DateFormat.MMM('es').format(c.nextDate!).replaceAll('.', '')}',
      ChipTone.good,
    ),
    ChargeStatus.unknown => (c.detected ? 'detectada en tus movimientos' : 'se registra sola', ChipTone.neutral),
  };
  return TicketData(
    variant: variant,
    merchant: c.name,
    meta: '$where · ${frequencyWords[c.frequency] ?? 'recurrente'}',
    lead: lead,
    accent: accent,
    amount: formatMoney(c.amount, c.currency.isEmpty ? null : c.currency),
    currency: c.currency,
    chip: chip,
    chipTone: tone,
    weekday: status == ChargeStatus.paid ? 'pagado' : (days == 0 ? 'hoy' : DateFormat.EEEE('es').format(c.date)),
    day: '${c.date.day}',
    month: month,
  );
}

// ─── Avisos programados ─────────────────────────────────────────────────────────────────────────

/// Un aviso del sistema por programar.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.route,
    this.charge,
    this.ticket,
    this.lines = const [],
    this.moveRoute,
  });

  final int id;

  /// Momento del aviso (hora local).
  final DateTime at;
  final String title, body;

  /// Pantalla que abre al tocarlo.
  final String route;

  /// Cobro del aviso (null en el resumen semanal).
  final Charge? charge;
  final TicketData? ticket;

  /// Líneas del resumen semanal.
  final List<String> lines;

  /// Formulario para cubrir lo que falta (solo si no alcanza).
  final String? moveRoute;

  bool get alert => charge?.short ?? false;
}

/// Primer id de los avisos programados (los anteriores quedan para la prueba y «recordar más tarde»).
const firstReminderId = 1000;

/// Avisos a programar según los ajustes: el día antes y/o el mismo día a la hora elegida, y un
/// resumen los lunes cuando la semana trae dos cobros o más. Ordenados por hora, como mucho [limit].
List<PlannedReminder> planReminders(
  List<Charge> charges,
  ReminderSettings s, {
  required DateTime now,
  double? hourlyRate,
  int limit = 40,
  int horizonDays = 31,
}) {
  if (!s.enabled) return const [];
  final wanted = charges.where((c) => !c.paid && (c.detected ? s.subscriptions : s.recurring) && daysBetween(now, c.date) >= 0).toList();
  DateTime at(DateTime day) => DateTime(day.year, day.month, day.day, s.hour);
  final out = <PlannedReminder>[];
  void add(Charge c, DateTime day) {
    final when = at(day);
    if (!when.isAfter(now)) return;
    out.add(
      PlannedReminder(
        id: 0,
        at: when,
        title: chargeTitle(c, day),
        body: chargeBody(c, day, hourlyRate: hourlyRate),
        route: chargesRoute(c.date),
        charge: c,
        ticket: ticketFor(c, day),
        moveRoute: c.short && c.accountId != null ? moveMoneyRoute(c) : null,
      ),
    );
  }

  for (final c in wanted) {
    if (s.dayBefore) add(c, _addDays(c.date, -1));
    if (s.sameDay) add(c, c.date);
  }

  // Resumen de la semana: los lunes, con los cobros de lunes a domingo
  final today = dayOf(now);
  for (var d = today; daysBetween(today, d) <= horizonDays; d = _addDays(d, 1)) {
    if (d.weekday != DateTime.monday || !at(d).isAfter(now)) continue;
    final week = wanted.where((c) => daysBetween(d, c.date) >= 0 && daysBetween(d, c.date) < 7).toList();
    if (week.length < 2) continue;
    out.add(
      PlannedReminder(
        id: 0,
        at: at(d),
        title: 'Esta semana: ${week.length} cobros por ${_totalsCode(week)}',
        body: _names(week.take(4).toList()) + (week.length > 4 ? ' y más' : ''),
        route: chargesRoute(d),
        lines: [for (final c in week.take(7)) '${c.name} · ${whenWord(c.date, d)}: ${formatMoneyCode(c.amount, c.currency)}'],
      ),
    );
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return [
    for (final (i, r) in out.take(limit).indexed)
      PlannedReminder(
        id: firstReminderId + i,
        at: r.at,
        title: r.title,
        body: r.body,
        route: r.route,
        charge: r.charge,
        ticket: r.ticket,
        lines: r.lines,
        moveRoute: r.moveRoute,
      ),
  ];
}

String _totalsCode(List<Charge> charges) {
  final totals = <String, double>{};
  for (final c in charges) {
    totals[c.currency] = (totals[c.currency] ?? 0) + c.amount;
  }
  return totals.entries.map((e) => formatMoneyCode(e.value, e.key)).join(' + ');
}

/// Aviso de ejemplo para «Probar un aviso» cuando aún no hay cobros previstos.
Charge sampleCharge(DateTime today) => Charge(
  key: 'demo',
  source: ChargeSource.recurring,
  name: 'Netflix',
  amount: 44900,
  currency: 'COP',
  date: _addDays(dayOf(today), 1),
  frequency: 'monthly',
  accountName: 'Bancolombia',
  remaining: 1204300,
);
