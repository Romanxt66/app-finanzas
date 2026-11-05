import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../ui/charge_ticket.dart';
import 'reminder_scheduler.dart';
import 'reminders.dart';

ReminderScheduler createScheduler() => Platform.isAndroid ? AndroidReminderScheduler() : const NoopScheduler();

/// Id del aviso de prueba («Probar un aviso») y del «recordar a las 6 p. m.» de la hoja.
const testReminderId = 1;
const laterReminderId = 2;

/// Los avisos pospuestos («Recordar en 3 h») usan ids desde aquí: no los borra la reprogramación.
const snoozeBase = 900000;

/// Imágenes de tarjeta por sincronización: las de los avisos siguientes (las demás van sin imagen
/// grande y se generan cuando la app vuelva a abrirse).
const _maxPictures = 10;

const _init = InitializationSettings(android: AndroidInitializationSettings('ic_stat_alvea'));

/// Lo que viaja con cada aviso: basta para volver a mostrarlo (al posponerlo) y para abrir la app.
class ReminderPayload {
  const ReminderPayload({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    this.move,
    this.picture,
    this.icon,
    this.alert = false,
    this.hide = false,
    this.lines = const [],
  });

  static ReminderPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return ReminderPayload(
        id: j['id'] as int,
        title: j['title'] as String,
        body: j['body'] as String,
        route: j['route'] as String,
        move: j['move'] as String?,
        picture: j['picture'] as String?,
        icon: j['icon'] as String?,
        alert: j['alert'] == true,
        hide: j['hide'] == true,
        lines: [for (final l in (j['lines'] as List?) ?? const []) '$l'],
      );
    } catch (_) {
      return null;
    }
  }

  final int id;
  final String title, body, route;
  final String? move, picture, icon;
  final bool alert, hide;
  final List<String> lines;

  String encode() => jsonEncode({
    'id': id,
    'title': title,
    'body': body,
    'route': route,
    'move': move,
    'picture': picture,
    'icon': icon,
    'alert': alert,
    'hide': hide,
    'lines': lines,
  });
}

AndroidBitmap<Object>? _file(String? path) => path != null && File(path).existsSync() ? FilePathAndroidBitmap(path) : null;

/// Cómo se ve el aviso: tarjeta de cristal como imagen grande, Alvi en su burbuja como icono,
/// color e icono de Alvea y las acciones.
NotificationDetails reminderDetails(ReminderPayload p) {
  final picture = _file(p.picture);
  final icon = _file(p.icon);
  final StyleInformation style = picture != null
      ? BigPictureStyleInformation(picture, contentTitle: p.title, summaryText: p.body, hideExpandedLargeIcon: true)
      : p.lines.isNotEmpty
      ? InboxStyleInformation(p.lines, contentTitle: p.title, summaryText: p.body)
      : BigTextStyleInformation(p.body, contentTitle: p.title);
  return NotificationDetails(
    android: AndroidNotificationDetails(
      p.alert ? 'cobros_alerta' : 'cobros',
      p.alert ? 'Cobros que no alcanzan' : 'Recordatorios de cobro',
      channelDescription: p.alert
          ? 'Cuando el saldo de la cuenta no cubre un cobro próximo'
          : 'Antes de que se cobre un pago recurrente o una suscripción',
      importance: p.alert ? Importance.high : Importance.defaultImportance,
      priority: p.alert ? Priority.high : Priority.defaultPriority,
      icon: 'ic_stat_alvea',
      color: p.alert ? const Color(0xFF626262) : const Color(0xFF434343),
      largeIcon: icon,
      styleInformation: style,
      visibility: p.hide ? NotificationVisibility.private : NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      groupKey: 'click.softlane.alvea.cobros',
      actions: [
        if (p.move != null) const AndroidNotificationAction('mover', 'Mover dinero', showsUserInterface: true),
        const AndroidNotificationAction('ver', 'Ver detalle', showsUserInterface: true),
        const AndroidNotificationAction('luego', 'Recordar en 3 h'),
      ],
    ),
  );
}

tz.TZDateTime _at(DateTime when) => tz.TZDateTime.from(when, tz.UTC);

Future<void> _scheduleAt(FlutterLocalNotificationsPlugin plugin, int id, DateTime when, ReminderPayload p) => plugin.zonedSchedule(
  id: id,
  scheduledDate: _at(when),
  notificationDetails: reminderDetails(p),
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  title: p.title,
  body: p.body,
  payload: p.encode(),
);

/// «Recordar en 3 h»: vuelve a programar el mismo aviso (con el mismo contenido) tres horas después.
Future<void> _snooze(FlutterLocalNotificationsPlugin plugin, NotificationResponse r) async {
  final p = ReminderPayload.decode(r.payload);
  if (p == null) return;
  await _scheduleAt(plugin, snoozeBase + p.id % 1000, DateTime.now().add(const Duration(hours: 3)), p);
}

/// Acciones tocadas con la app cerrada: se ejecutan en segundo plano (solo «Recordar en 3 h»).
@pragma('vm:entry-point')
Future<void> reminderBackgroundResponse(NotificationResponse r) async {
  if (r.actionId != 'luego') return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings: _init, onDidReceiveBackgroundNotificationResponse: reminderBackgroundResponse);
  await _snooze(plugin, r);
}

/// Ruta que abre un aviso tocado (o su acción).
String? _routeOf(NotificationResponse r) {
  final p = ReminderPayload.decode(r.payload);
  if (p == null || r.actionId == 'luego') return null;
  return r.actionId == 'mover' ? (p.move ?? p.route) : p.route;
}

class AndroidReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  bool get supported => true;

  @override
  Future<void> init(void Function(String route) onOpen) async {
    if (_ready) return;
    await _plugin.initialize(
      settings: _init,
      onDidReceiveNotificationResponse: (r) {
        if (r.actionId == 'luego') {
          _snooze(_plugin, r);
          return;
        }
        final route = _routeOf(r);
        if (route != null) onOpen(route);
      },
      onDidReceiveBackgroundNotificationResponse: reminderBackgroundResponse,
    );
    _ready = true;
  }

  @override
  Future<String?> launchRoute() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    final r = d?.notificationResponse;
    return d?.didNotificationLaunchApp == true && r != null ? _routeOf(r) : null;
  }

  @override
  Future<bool?> permission() async => _android?.areNotificationsEnabled();

  @override
  Future<bool> requestPermission() async => await _android?.requestNotificationsPermission() ?? false;

  Future<Directory> _dir() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/avisos');
    await dir.create(recursive: true);
    return dir;
  }

  /// Imagen de la tarjeta; el nombre sale del contenido, así una tarjeta igual reutiliza su archivo.
  Future<String> _ticket(Directory dir, TicketData data) async {
    final name = sha1.convert(utf8.encode(data.signature)).toString().substring(0, 20);
    final file = File('${dir.path}/cobro_$name.png');
    if (!await file.exists()) {
      final png = await paintToPng(ChargeTicketPainter(data, background: await loadTicketBackground()), ticketSize);
      await file.writeAsBytes(png, flush: true);
    }
    return file.path;
  }

  Future<String> _bubble(Directory dir, TicketVariant v) async {
    final file = File('${dir.path}/alvi_${v.name}.png');
    if (!await file.exists()) await file.writeAsBytes(await paintToPng(AlviBubblePainter(v), const Size.square(192)), flush: true);
    return file.path;
  }

  Future<ReminderPayload> _payload(Directory dir, PlannedReminder r, {required bool hide, required bool picture}) async => ReminderPayload(
    id: r.id,
    title: r.title,
    body: r.body,
    route: r.route,
    move: r.moveRoute,
    picture: picture && r.ticket != null ? await _ticket(dir, r.ticket!) : null,
    icon: await _bubble(dir, r.ticket?.variant ?? TicketVariant.covered),
    alert: r.alert,
    hide: hide,
    lines: r.lines,
  );

  @override
  Future<void> schedule(List<PlannedReminder> plan, {required bool hideAmounts}) async {
    final dir = await _dir();
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= firstReminderId && p.id < snoozeBase) await _plugin.cancel(id: p.id);
    }
    final used = <String>{};
    var pictures = 0;
    for (final r in plan) {
      if (!r.at.isAfter(DateTime.now().add(const Duration(seconds: 5)))) continue;
      final p = await _payload(dir, r, hide: hideAmounts, picture: pictures < _maxPictures);
      if (p.picture != null) pictures++;
      used.addAll([?p.picture, ?p.icon]);
      await _scheduleAt(_plugin, r.id, r.at, p);
    }
    // Limpia las imágenes viejas que ya no usa ningún aviso pendiente (las recientes pueden estar en la persiana)
    final old = DateTime.now().subtract(const Duration(days: 2));
    await for (final f in dir.list()) {
      if (f is File && !used.contains(f.path) && f.path.contains('cobro_') && (await f.lastModified()).isBefore(old)) {
        await f.delete();
      }
    }
  }

  @override
  Future<void> show(PlannedReminder r, {required bool hideAmounts, bool later = false}) async {
    final p = await _payload(await _dir(), r, hide: hideAmounts, picture: true);
    if (later && r.at.isAfter(DateTime.now())) {
      await _scheduleAt(_plugin, r.id, r.at, p);
    } else {
      await _plugin.show(id: r.id, title: p.title, body: p.body, notificationDetails: reminderDetails(p), payload: p.encode());
    }
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    try {
      final dir = await _dir();
      await dir.delete(recursive: true);
    } catch (_) {}
  }

  @override
  Future<void> openSystemSettings() async => _plugin.openAppNotificationSettings();
}
