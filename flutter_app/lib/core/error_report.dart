import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Envía al servidor los errores no controlados de la app (`POST /api/v1/client-errors`), para
/// enterarse de los fallos sin que nadie tenga que avisar. Sin datos de la cuenta: solo el mensaje,
/// la traza, la ruta y la plataforma. Como mucho [_maxPerSession] por sesión y sin repetidos.
class ErrorReporter {
  ErrorReporter({http.Client? client, this._baseUrl, this.route}) : _client = client ?? http.Client();

  static const _maxPerSession = 10;
  static const _release = String.fromEnvironment('APP_RELEASE');
  static const _apiUrl = String.fromEnvironment('API_URL');

  final http.Client _client;
  final String? _baseUrl;

  /// Ruta actual de la app (la aporta el router).
  final String Function()? route;
  final Set<String> _sent = {};

  String get _base => _baseUrl ?? (_apiUrl.isNotEmpty ? _apiUrl : Uri.base.origin);

  Future<void> report(Object error, StackTrace? stack) async {
    final message = error.toString();
    final key = message.length > 200 ? message.substring(0, 200) : message;
    if (_sent.length >= _maxPerSession || !_sent.add(key)) return;
    String cut(String s, int max) => s.length > max ? s.substring(0, max) : s;
    try {
      await _client.post(
        Uri.parse('$_base/api/v1/client-errors'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': cut(message, 1000),
          'stack': cut(stack?.toString() ?? '', 8000),
          'route': cut(route?.call() ?? '', 200),
          'release': cut(_release, 40),
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        }),
      );
    } catch (_) {
      // Sin conexión no hay a quién avisar: el error ya se mostró en la consola.
    }
  }
}
