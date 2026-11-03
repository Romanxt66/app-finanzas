import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Movimientos guardados sin conexión (desde el recuadro rápido): se envían en cuanto se pueda.
class PendingQueue {
  PendingQueue(this._prefs, this._api);
  final SharedPreferences _prefs;
  final ApiClient _api;

  static const _key = 'pending_transactions';

  List<Map<String, dynamic>> get items {
    try {
      return [for (final j in jsonDecode(_prefs.getString(_key) ?? '[]') as List) Map<String, dynamic>.from(j as Map)];
    } catch (_) {
      return [];
    }
  }

  int get length => items.length;

  Future<void> _save(List<Map<String, dynamic>> list) => list.isEmpty ? _prefs.remove(_key) : _prefs.setString(_key, jsonEncode(list));

  Future<void> add(Map<String, dynamic> body) => _save([...items, body]);

  /// Envía los pendientes en orden. Devuelve cuántos se enviaron; se detiene al primer fallo de red.
  /// Uno que el servidor rechaza (p. ej. la cuenta ya no existe) se descarta para no bloquear la cola.
  Future<int> flush() async {
    var list = items;
    var sent = 0;
    while (list.isNotEmpty) {
      try {
        await _api.post('/transactions', body: list.first);
        sent++;
      } on ApiError catch (e) {
        if (e.status == 0 || e.status == 401 || e.status >= 500) break;
      }
      list = list.sublist(1);
      await _save(list);
    }
    return sent;
  }
}
