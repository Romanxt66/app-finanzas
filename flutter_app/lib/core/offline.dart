import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

// Modo sin conexión: lo último que se leyó de cada pantalla queda guardado en el teléfono y los cambios
// hechos sin señal esperan en una cola que se envía sola, en orden, al volver la conexión.

/// Lecturas guardadas (respuesta de cada GET) para enseñarlas cuando no hay conexión.
class OfflineCache {
  OfflineCache(this._prefs);
  final SharedPreferences _prefs;

  static const _prefix = 'offline_cache:';
  static const _indexKey = 'offline_cache_index';

  /// Cuántas lecturas distintas se guardan (las más antiguas se descartan).
  static const maxEntries = 160;

  /// Respuestas más grandes no se guardan (p. ej. una exportación enorme).
  static const maxChars = 400000;

  List<String> get _index => _prefs.getStringList(_indexKey) ?? const [];

  dynamic read(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  bool has(String key) => _prefs.containsKey('$_prefix$key');

  Future<void> write(String key, dynamic body) async {
    final raw = jsonEncode(body);
    if (raw.length > maxChars) return;
    final index = [..._index.where((k) => k != key), key];
    while (index.length > maxEntries) {
      await _prefs.remove('$_prefix${index.removeAt(0)}');
    }
    await _prefs.setString('$_prefix$key', raw);
    await _prefs.setStringList(_indexKey, index);
  }

  /// Al cerrar sesión (o entrar con otra cuenta) no queda nada del usuario anterior.
  Future<void> clear() async {
    for (final k in _index) {
      await _prefs.remove('$_prefix$k');
    }
    await _prefs.remove(_indexKey);
  }
}

/// Un cambio hecho sin conexión, a la espera de enviarse.
class OutboxItem {
  OutboxItem({required this.id, required this.method, required this.path, this.body, String? createdAt, this.tempId})
    : createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory OutboxItem.fromJson(Map<String, dynamic> j) => OutboxItem(
    id: j['id'] as String,
    method: j['method'] as String,
    path: j['path'] as String,
    body: j['body'],
    createdAt: j['created_at'] as String?,
    tempId: j['temp_id'] as String?,
  );

  /// También es la clave de idempotencia: reenviarlo no lo duplica en el servidor.
  final String id;
  final String method;
  String path;
  Object? body;
  final String createdAt;

  /// Id provisional del elemento que crea (POST), para enlazar los cambios que dependen de él.
  final String? tempId;

  Map<String, dynamic> toJson() => {'id': id, 'method': method, 'path': path, 'body': ?body, 'created_at': createdAt, 'temp_id': ?tempId};
}

/// Resultado de enviar la cola.
class FlushResult {
  const FlushResult({this.sent = 0, this.rejected = 0, this.stopped = false});
  final int sent;

  /// Cambios que el servidor no aceptó (p. ej. la cuenta ya no existe): se descartan para no bloquear.
  final int rejected;

  /// Se cortó por falta de conexión o de sesión: queda pendiente lo que no se envió.
  final bool stopped;
}

/// Envío de un cambio: devuelve la respuesta, o lanza con el estado HTTP (0 = sin conexión).
typedef OutboxSender = Future<dynamic> Function(OutboxItem item);

/// Error al enviar un elemento de la cola, con su estado HTTP (0 = sin conexión).
class OutboxSendError implements Exception {
  OutboxSendError(this.status);
  final int status;
}

const tempPrefix = 'tmp-';

String newOfflineId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Colecciones cuyos cambios se pueden hacer sin conexión. Lo demás (sesión, seguridad, importar,
/// eliminar la cuenta…) necesita al servidor en el momento.
const _offlineCollections = {'transactions', 'accounts', 'categories', 'budgets', 'goals', 'recurring', 'waiting-room', 'life-hours'};

bool isQueueable(String method, String path) {
  if (method == 'GET') return false;
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty || !_offlineCollections.contains(parts.first)) return false;
  // `/recurring/run` registra lo vencido en el servidor: no tiene sentido sin él
  if (parts.length == 2 && parts.first == 'recurring' && parts[1] == 'run') return false;
  if (parts.first == 'life-hours' && !(method == 'PUT' && path == '/life-hours/profile')) return false;
  return true;
}

/// Cola de cambios pendientes, guardada en el teléfono (sobrevive a cerrar la app).
class Outbox {
  Outbox(this._prefs) {
    _migrateQuickAdd();
    count.value = items.length;
  }
  final SharedPreferences _prefs;

  static const _key = 'offline_outbox';

  /// Cola antigua del recuadro rápido (solo movimientos nuevos): se pasa a esta.
  static const _legacyKey = 'pending_transactions';

  /// Cuántos cambios esperan; la interfaz lo muestra.
  final count = ValueNotifier<int>(0);

  /// Sube con cada cambio de la cola (para saber si una escritura acabó en ella).
  int version = 0;

  bool _flushing = false;

  List<OutboxItem> get items {
    try {
      return [for (final j in jsonDecode(_prefs.getString(_key) ?? '[]') as List) OutboxItem.fromJson(Map<String, dynamic>.from(j as Map))];
    } catch (_) {
      return [];
    }
  }

  bool get isEmpty => items.isEmpty;

  Future<void> _save(List<OutboxItem> list) async {
    version++;
    count.value = list.length;
    if (list.isEmpty) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, jsonEncode([for (final i in list) i.toJson()]));
    }
  }

  void _migrateQuickAdd() {
    final raw = _prefs.getString(_legacyKey);
    if (raw == null) return;
    try {
      final old = [for (final j in jsonDecode(raw) as List) Map<String, dynamic>.from(j as Map)];
      final list = [...items, for (final body in old) OutboxItem(id: newOfflineId(), method: 'POST', path: '/transactions', body: body)];
      _prefs.setString(_key, jsonEncode([for (final i in list) i.toJson()]));
    } catch (_) {}
    _prefs.remove(_legacyKey);
  }

  /// Guarda un cambio. Devuelve lo que la app debe ver como respuesta: para una creación, el elemento
  /// con un id provisional (así se puede usar enseguida, p. ej. elegir la categoría recién creada).
  Future<dynamic> add(String method, String path, Object? body, {String? id}) async {
    var list = items;
    final pathTemp = _tempIn(path);
    // Cambios sobre algo creado sin conexión: se funden con su creación, que aún no se ha enviado
    if (pathTemp != null) {
      final creation = list.where((i) => i.tempId == pathTemp).firstOrNull;
      if (method == 'DELETE') {
        await _save(list.where((i) => !_mentions(i, pathTemp)).toList());
        return null;
      }
      if (creation != null && (method == 'PUT' || method == 'PATCH') && _isItemPath(path) && body is Map && creation.body is Map) {
        creation.body = {...(creation.body as Map), ...body};
        await _save(list);
        return <String, dynamic>{...Map<String, dynamic>.from(creation.body as Map), 'id': pathTemp};
      }
    }
    final isCreation = method == 'POST' && _isCollectionPath(path);
    final temp = isCreation ? '$tempPrefix${newOfflineId()}' : null;
    list = [...list, OutboxItem(id: id ?? newOfflineId(), method: method, path: path, body: body, tempId: temp)];
    await _save(list);
    if (temp != null && body is Map) return <String, dynamic>{...Map<String, dynamic>.from(body), 'id': temp, 'pending': true};
    return null;
  }

  /// Envía la cola en orden. Una creación que el servidor acepta cambia su id provisional por el real
  /// en todo lo que viene detrás. Se para al primer corte de conexión o si la sesión caducó.
  Future<FlushResult> flush(OutboxSender send) async {
    if (_flushing) return const FlushResult(stopped: true);
    _flushing = true;
    var sent = 0;
    var rejected = 0;
    try {
      var list = items;
      while (list.isNotEmpty) {
        final item = list.first;
        final pending = _tempIn(item.path) ?? _tempInBody(item.body);
        if (pending != null && !list.any((i) => i.tempId == pending)) {
          // Depende de algo creado sin conexión que el servidor rechazó: tampoco puede aplicarse
          rejected++;
        } else {
          try {
            final res = await send(item);
            sent++;
            final real = res is Map ? res['id'] : null;
            if (item.tempId != null && real is String) {
              list = [for (final i in list.skip(1)) _rewrite(i, item.tempId!, real)];
              list = [item, ...list];
            }
          } on OutboxSendError catch (e) {
            if (e.status == 0 || e.status == 401 || e.status == 408 || e.status == 429 || e.status >= 500) {
              return FlushResult(sent: sent, rejected: rejected, stopped: true);
            }
            rejected++;
          }
        }
        list = list.sublist(1);
        await _save(list);
      }
      return FlushResult(sent: sent, rejected: rejected);
    } finally {
      _flushing = false;
    }
  }

  Future<void> clear() => _save(const []);

  /// Aplica los cambios aún no enviados sobre una lectura (del servidor o guardada), para que la app
  /// muestre lo que el usuario ya hizo aunque el servidor todavía no lo sepa.
  dynamic overlay(String path, Map<String, String> query, dynamic body) {
    final list = items;
    if (list.isEmpty || body == null) return body;
    return applyOverlay(list, path, query, body);
  }
}

String? _tempIn(String path) {
  final m = RegExp('$tempPrefix[0-9a-f]+').firstMatch(path);
  return m?.group(0);
}

String? _tempInBody(Object? body) {
  if (body == null) return null;
  final m = RegExp('$tempPrefix[0-9a-f]+').firstMatch(jsonEncode(body));
  return m?.group(0);
}

bool _mentions(OutboxItem i, String temp) => i.tempId == temp || i.path.contains(temp) || jsonEncode(i.body).contains(temp);

OutboxItem _rewrite(OutboxItem i, String temp, String real) {
  i.path = i.path.replaceAll(temp, real);
  if (i.body != null) i.body = jsonDecode(jsonEncode(i.body).replaceAll(temp, real));
  return i;
}

List<String> _segments(String path) => path.split('/').where((p) => p.isNotEmpty).toList();

/// `/accounts`: la colección entera.
bool _isCollectionPath(String path) => _segments(path).length == 1;

/// `/accounts/{id}`: un elemento.
bool _isItemPath(String path) => _segments(path).length == 2;

/// Valores con los que una creación sin conexión se ve como un elemento normal de su lista.
Map<String, dynamic>? _synthetic(String collection, String id, Map body) {
  final b = Map<String, dynamic>.from(body);
  switch (collection) {
    case 'transactions':
      return {
        'transfer_account_id': null,
        'category_id': null,
        'description': '',
        'mood': null,
        ...b,
        'id': id,
        'amount': '${b['amount']}',
        'pending': true,
      };
    case 'accounts':
      return {'archived': false, ...b, 'id': id, 'balance': '${b['initial_balance'] ?? '0'}', 'pending': true};
    case 'categories':
      return {...b, 'id': id, 'pending': true};
    case 'budgets':
      return {...b, 'id': id, 'amount': '${b['amount']}', 'spent': '0', 'pending': true};
    default:
      return null; // metas, recurrentes…: aparecen al sincronizar
  }
}

/// ¿El elemento creado sin conexión entra en esta lectura filtrada?
bool _matches(Map<String, dynamic> item, Map<String, String> query) {
  for (final e in query.entries) {
    final v = e.value;
    switch (e.key) {
      case 'limit':
      case 'include_archived':
        break;
      case 'offset':
        if (v != '0') return false;
      case 'date_from':
        if ('${item['occurred_on']}'.compareTo(v) < 0) return false;
      case 'date_to':
        if ('${item['occurred_on']}'.compareTo(v) > 0) return false;
      case 'search':
        if (!'${item['description']}'.toLowerCase().contains(v.toLowerCase())) return false;
      case 'account_id':
        if (item['account_id'] != v && item['transfer_account_id'] != v) return false;
      case 'month':
        if (item.containsKey('month') && !'${item['month']}'.startsWith(v.substring(0, min(7, v.length)))) return false;
      default:
        if (item.containsKey(e.key) && '${item[e.key]}' != v) return false;
    }
  }
  return true;
}

@visibleForTesting
dynamic applyOverlay(List<OutboxItem> pending, String path, Map<String, String> query, dynamic body) {
  final seg = _segments(path);
  if (seg.length != 1) return body; // solo listas: `/accounts`, `/transactions`…
  final collection = seg.first;
  final isPage = body is Map && body['items'] is List;
  final source = isPage ? body['items'] as List : (body is List ? body : null);
  if (source == null) return body;
  var list = [for (final x in source) x is Map ? Map<String, dynamic>.from(x) : x];
  var added = 0;
  var removed = 0;
  for (final op in pending) {
    final s = _segments(op.path);
    if (s.isEmpty || s.first != collection) continue;
    if (op.method == 'POST' && s.length == 1 && op.tempId != null && op.body is Map) {
      final item = _synthetic(collection, op.tempId!, op.body as Map);
      if (item != null && _matches(item, query)) {
        list = collection == 'transactions' ? [item, ...list] : [...list, item];
        added++;
      }
    } else if (s.length == 2 && (op.method == 'PUT' || op.method == 'PATCH') && op.body is Map) {
      list = [
        for (final x in list)
          if (x is Map && x['id'] == s[1]) {...x, ...(op.body as Map), 'pending': true} else x,
      ];
    } else if (s.length == 2 && op.method == 'DELETE') {
      final before = list.length;
      list = [
        for (final x in list)
          if (!(x is Map && x['id'] == s[1])) x,
      ];
      removed += before - list.length;
    }
  }
  if (!isPage) return list;
  return {...body, 'items': list, 'total': ((body['total'] as num?) ?? 0) + added - removed};
}
