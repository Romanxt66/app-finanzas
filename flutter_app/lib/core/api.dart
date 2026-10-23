import 'dart:convert';

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
    _memAccess = null;
    _memRefresh = null;
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
  }

  String get _base => _baseUrl ?? (_apiUrl.isNotEmpty ? _apiUrl : Uri.base.origin);

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
  Future<dynamic> call(String method, String path, {Object? body, Map<String, Object?>? query, bool auth = true}) async {
    final uri = _uri(path, query);
    var res = await _send(method, uri, body, auth);
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
