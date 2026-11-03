import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'browser_notify_stub.dart' if (dart.library.js_interop) 'browser_notify_web.dart';
import 'format.dart';

/// Aviso calculado por el servidor (cobro próximo, presupuesto casi agotado, compra lista…).
@immutable
class Notice {
  Notice.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      kind = j['kind'] as String,
      severity = j['severity'] as String,
      title = j['title'] as String,
      body = j['body'] as String,
      link = j['link'] as String,
      date = j['date'] as String;
  final String id, kind, severity, title, body, link, date;

  bool get urgent => severity != 'info';
}

/// Avisos pendientes y cuáles ya se leyeron (en este dispositivo).
class NoticeCenter extends ChangeNotifier {
  NoticeCenter(this._prefs, this._api) : _read = (_prefs.getStringList(_readKey) ?? const []).toSet() {
    browserAlerts = _prefs.getString(_browserKey) == '1';
  }

  static const _readKey = 'notices_read';
  static const _shownKey = 'notices_shown';
  static const _browserKey = 'notices_browser';

  final SharedPreferences _prefs;
  final ApiClient _api;
  final Set<String> _read;

  List<Notice> items = const [];
  bool loaded = false;

  /// El usuario pidió avisos del navegador (y concedió el permiso).
  bool browserAlerts = false;

  int get unread => items.where((n) => !_read.contains(n.id)).length;
  bool isRead(Notice n) => _read.contains(n.id);

  /// El aviso no leído más importante (para que Alvi lo mencione), o null.
  Notice? get top => items.where((n) => !_read.contains(n.id)).firstOrNull;

  Future<void> load() async {
    try {
      final res = await _api.get('/notifications', query: {'today': todayISO()}) as Map<String, dynamic>;
      items = [for (final j in res['items'] as List<dynamic>) Notice.fromJson(j as Map<String, dynamic>)];
      loaded = true;
      // Olvida los leídos que ya no existen: la lista no crece sin fin
      final live = items.map((n) => n.id).toSet();
      _read.retainAll(live);
      await _prefs.setStringList(_readKey, _read.toList());
      notifyListeners();
      _alertNew();
    } catch (_) {
      // Los avisos son secundarios: sin conexión se conservan los últimos cargados.
    }
  }

  Future<void> markRead(Notice n) async {
    if (_read.add(n.id)) {
      await _prefs.setStringList(_readKey, _read.toList());
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    _read.addAll(items.map((n) => n.id));
    await _prefs.setStringList(_readKey, _read.toList());
    notifyListeners();
  }

  void clear() {
    items = const [];
    loaded = false;
    notifyListeners();
  }

  /// Permiso del navegador para mostrar avisos del sistema ('granted', 'denied', 'default' o 'unsupported').
  static String get browserPermission => kIsWeb ? notificationPermission() : 'unsupported';

  /// Activa o desactiva los avisos del navegador; al activar pide permiso. Devuelve si quedaron activos.
  Future<bool> setBrowserAlerts(bool on) async {
    if (on && browserPermission != 'granted') {
      if (browserPermission == 'unsupported') return false;
      on = await requestNotificationPermission() == 'granted';
    }
    browserAlerts = on;
    await _prefs.setString(_browserKey, on ? '1' : '0');
    notifyListeners();
    if (on) _alertNew();
    return on;
  }

  /// Muestra como aviso del sistema los urgentes que aún no se mostraron (una vez cada uno).
  void _alertNew() {
    if (!browserAlerts || browserPermission != 'granted') return;
    final shown = (_prefs.getStringList(_shownKey) ?? const []).toSet();
    final fresh = items.where((n) => n.urgent && !_read.contains(n.id) && !shown.contains(n.id)).take(3).toList();
    for (final n in fresh) {
      showNotification(n.title, n.body, n.id);
      shown.add(n.id);
    }
    if (fresh.isNotEmpty) {
      shown.retainAll(items.map((n) => n.id));
      _prefs.setStringList(_shownKey, shown.toList());
    }
  }
}
