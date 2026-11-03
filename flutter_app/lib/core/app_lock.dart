import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bloqueo de la app con un PIN de este dispositivo: se pide al abrirla y al volver a ella tras
/// [delay] fuera. Tras [maxAttempts] intentos fallidos se cierra la sesión.
class AppLock extends ChangeNotifier {
  AppLock(this._prefs) {
    final seconds = _prefs.getInt(_delayKey);
    if (seconds != null) delay = Duration(seconds: seconds);
    locked = enabled;
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
  }

  static const _hashKey = 'pin_hash';
  static const _delayKey = 'pin_delay';
  static const maxAttempts = 5;
  static const _iterations = 20000;

  /// Opciones de espera antes de volver a pedir el PIN.
  static const delays = [Duration.zero, Duration(minutes: 1), Duration(minutes: 5), Duration(minutes: 15)];

  final SharedPreferences _prefs;
  late final AppLifecycleListener _lifecycle;

  bool locked = false;
  int failures = 0;
  Duration delay = const Duration(minutes: 1);
  DateTime? _hiddenAt;

  /// Se invoca al agotar los intentos (la app cierra la sesión).
  VoidCallback? onTooManyAttempts;

  bool get enabled => _prefs.getString(_hashKey) != null;
  int get attemptsLeft => maxAttempts - failures;

  void _onHide() => _hiddenAt ??= DateTime.now();

  void _onShow() {
    final since = _hiddenAt;
    _hiddenAt = null;
    if (enabled && !locked && since != null && DateTime.now().difference(since) >= delay) lock();
  }

  void lock() {
    if (!enabled) return;
    locked = true;
    notifyListeners();
  }

  static String _derive(String pin, List<int> salt) {
    var digest = sha256.convert([...salt, ...utf8.encode(pin)]).bytes;
    for (var i = 1; i < _iterations; i++) {
      digest = sha256.convert([...digest, ...salt]).bytes;
    }
    return base64Encode(digest);
  }

  static bool validPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  Future<void> setPin(String pin) async {
    assert(validPin(pin));
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    await _prefs.setString(_hashKey, '${base64Encode(salt)}:${_derive(pin, salt)}');
    failures = 0;
    locked = false;
    notifyListeners();
  }

  bool _matches(String pin) {
    final stored = _prefs.getString(_hashKey);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final expected = _derive(pin, base64Decode(parts[0]));
    // Comparación en tiempo constante
    var diff = expected.length ^ parts[1].length;
    for (var i = 0; i < expected.length && i < parts[1].length; i++) {
      diff |= expected.codeUnitAt(i) ^ parts[1].codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Intenta desbloquear; devuelve si el PIN era correcto.
  bool unlock(String pin) {
    if (_matches(pin)) {
      failures = 0;
      locked = false;
      notifyListeners();
      return true;
    }
    failures++;
    if (failures >= maxAttempts) {
      failures = 0;
      onTooManyAttempts?.call();
    }
    notifyListeners();
    return false;
  }

  /// Comprueba el PIN sin cambiar el estado (para cambiarlo o desactivarlo).
  bool check(String pin) => _matches(pin);

  Future<void> disable() async {
    await _prefs.remove(_hashKey);
    locked = false;
    failures = 0;
    notifyListeners();
  }

  Future<void> setDelay(Duration value) async {
    delay = value;
    await _prefs.setInt(_delayKey, value.inSeconds);
    notifyListeners();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }
}
