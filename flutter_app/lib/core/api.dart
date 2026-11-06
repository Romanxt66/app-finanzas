import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// URL base del backend. Vacío = mismo origen (nginx reenvía /api al backend, sin CORS).
const _apiUrl = String.fromEnvironment('API_URL');

const networkMessage = 'No se pudo conectar con el servidor. Inténtalo de nuevo en unos minutos.';

class ApiError implements Exception {
  ApiError(this.status, this.code, this.message, [this.details = const []]);
  final int status;
  final String code;
  final String message;
  final List<({String field, String msg})> details;

  @override
  String toString() => message;
}

String _fallbackMessage(int status) {
  if ([502, 503, 504].contains(status)) return networkMessage;
  if (status == 429) {
    return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
  }
  if (status >= 500) return 'Error del servidor. Inténtalo de nuevo más tarde.';
  return 'La solicitud no se pudo completar (código $status).';
}

class ApiClient {
  ApiClient(this._prefs, {http.Client? client, this._baseUrl}) : _http = client ?? http.Client();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final SharedPreferences _prefs;
  final http.Client _http;
  final String? _baseUrl;
  Future<bool>? _refreshing;

  /// Se invoca cuando la sesión ya no es recuperable (refresh inválido).
  void Function() onUnauthorized = () {};

  // Sin «mantener sesión» los tokens viven solo en memoria (mueren con la pestaña).
  String? _memAccess;
  String? _memRefresh;

  String? get _access => _memAccess ?? _prefs.getString(_accessKey);
  String? get _refresh => _memRefresh ?? _prefs.getString(_refreshKey);
  bool get hasSession => _refresh != null;

  /// La sesión está guardada en el dispositivo («mantener sesión»), no solo en memoria.
  bool get remembered => _prefs.getString(_refreshKey) != null;

  /// Lecturas recientes: las pantallas que piden lo mismo a la vez (o casi) comparten la respuesta.
  /// Cualquier escritura las descarta, así que nunca se ve un dato anterior a un cambio propio.
  final _recent = <String, (DateTime, Future<dynamic>)>{};

  /// Último fallo al leer datos (sin conexión o servidor caído), para avisar en vez de mostrar ceros.
  /// Vuelve a null en cuanto una lectura sale bien.
  final loadError = ValueNotifier<ApiError?>(null);

  /// Esperas entre reintentos de una lectura que falla por algo pasajero.
  static List<Duration> retryDelays = const [Duration(milliseconds: 600), Duration(milliseconds: 1800)];
  static const _reuseFor = Duration(seconds: 2);

  /// [remember] indefinido conserva el almacén actual (al renovar el token no cambia de lugar).
  Future<void> saveTokens(Map<String, dynamic> pair, {bool? remember}) async {
    final access = pair['access_token'] as String;
    final refresh = pair['refresh_token'] as String;
    final memoryOnly = remember == null ? _memRefresh != null : !remember;
    if (memoryOnly) {
      _memAccess = access;
      _memRefresh = refresh;
      await _prefs.remove(_accessKey);
      await _prefs.remove(_refreshKey);
    } else {
      _memAccess = null;
      _memRefresh = null;
      await _prefs.setString(_accessKey, access);
      await _prefs.setString(_refreshKey, refresh);
    }
  }

  Future<void> clearTokens() async {
    _recent.clear();
    _memAccess = null;
    _memRefresh = null;
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
  }

  String get _base {
    if (_baseUrl != null) return _baseUrl;
    if (_apiUrl.isNotEmpty) return _apiUrl;
    // La app nativa no tiene «mismo origen»: necesita la URL del servidor al compilar
    if (!kIsWeb) throw StateError('Compila la app con --dart-define=API_URL=https://… (ver ANDROID.md)');
    return Uri.base.origin;
  }

  Uri _uri(String path, Map<String, Object?>? query) {
    final params = <String, String>{
      for (final e in (query ?? {}).entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    return Uri.parse('$_base/api/v1$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<http.Response> _send(String method, Uri uri, Object? body, bool auth) async {
    final req = http.Request(method, uri);
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (auth && _access != null) {
      req.headers['Authorization'] = 'Bearer $_access';
    }
    try {
      return await http.Response.fromStream(await _http.send(req));
    } catch (_) {
      throw ApiError(0, 'network', networkMessage);
    }
  }

  Future<bool> _refreshTokens() async {
    final refresh = _refresh;
    if (refresh == null) return false;
    try {
      final res = await _send('POST', _uri('/auth/refresh', null), {'refresh_token': refresh}, false);
      if (res.statusCode != 200) return false;
      await saveTokens(jsonDecode(res.body) as Map<String, dynamic>);
      return true;
    } on ApiError {
      return false;
    }
  }

  /// Petición JSON con renovación automática del token de acceso.
  Future<dynamic> call(String method, String path, {Object? body, Map<String, Object?>? query, bool auth = true}) {
    if (method != 'GET' || !auth) {
      _recent.clear();
      return _call(method, path, body: body, query: query, auth: auth).whenComplete(_recent.clear);
    }
    final key = _uri(path, query).toString();
    final now = DateTime.now();
    final hit = _recent[key];
    if (hit != null && now.difference(hit.$1) < _reuseFor) return hit.$2;
    final future = _call(method, path, query: query, auth: auth);
    _recent[key] = (now, future);
    // Un error no se reutiliza: el siguiente intento vuelve a preguntar
    future.catchError((Object _) {
      if (_recent[key]?.$2 == future) _recent.remove(key);
      return null;
    });
    return future;
  }

  /// Fallo pasajero: sin conexión, proxy o servidor reiniciando.
  static bool _transient(int status) => status == 0 || status == 502 || status == 503 || status == 504;

  /// Las lecturas (GET) se reintentan solas ante un fallo pasajero: un corte de un segundo o un reinicio
  /// del servidor no deben dejar la pantalla en cero. Las escrituras no se repiten (podrían duplicarse).
  Future<http.Response> _sendWithRetry(String method, Uri uri, Object? body, bool auth) async {
    final delays = method == 'GET' ? retryDelays : const <Duration>[];
    for (var attempt = 0; ; attempt++) {
      try {
        final res = await _send(method, uri, body, auth);
        if (!_transient(res.statusCode) || attempt >= delays.length) return res;
      } on ApiError {
        if (attempt >= delays.length) rethrow;
      }
      await Future<void>.delayed(delays[attempt]);
    }
  }

  Future<dynamic> _call(String method, String path, {Object? body, Map<String, Object?>? query, bool auth = true}) async {
    try {
      final result = await _callOnce(method, path, body: body, query: query, auth: auth);
      if (method == 'GET') loadError.value = null;
      return result;
    } on ApiError catch (e) {
      if (method == 'GET' && (_transient(e.status) || e.status >= 500)) loadError.value = e;
      rethrow;
    }
  }

  Future<dynamic> _callOnce(String method, String path, {Object? body, Map<String, Object?>? query, bool auth = true}) async {
    final uri = _uri(path, query);
    var res = await _sendWithRetry(method, uri, body, auth);
    if (res.statusCode == 401 && auth && _refresh != null) {
      _refreshing ??= _refreshTokens().whenComplete(() => _refreshing = null);
      if (await _refreshing!) res = await _send(method, uri, body, auth);
    }
    if (res.statusCode == 401 && auth) {
      await clearTokens();
      onUnauthorized();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic>? error;
      try {
        error = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['error'] as Map<String, dynamic>?;
      } catch (_) {}
      throw ApiError(
        res.statusCode,
        error?['code'] as String? ?? 'unknown',
        error?['message'] as String? ?? _fallbackMessage(res.statusCode),
        [for (final d in (error?['details'] as List<dynamic>? ?? [])) (field: '${(d as Map)['field']}', msg: '${d['msg']}')],
      );
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Descarga binaria autenticada (p. ej. exportar CSV), con la misma renovación de token.
  Future<List<int>> bytes(String path, {Map<String, Object?>? query}) async {
    final uri = _uri(path, query);
    var res = await _send('GET', uri, null, true);
    if (res.statusCode == 401 && _refresh != null) {
      _refreshing ??= _refreshTokens().whenComplete(() => _refreshing = null);
      if (await _refreshing!) res = await _send('GET', uri, null, true);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, 'download', _fallbackMessage(res.statusCode));
    }
    return res.bodyBytes;
  }

  Future<dynamic> get(String path, {Map<String, Object?>? query}) => call('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body, bool auth = true}) => call('POST', path, body: body, auth: auth);
  Future<dynamic> patch(String path, {Object? body}) => call('PATCH', path, body: body);
  Future<dynamic> delete(String path) => call('DELETE', path);
}
