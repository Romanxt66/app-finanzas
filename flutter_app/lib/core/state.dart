import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'format.dart';
import 'models.dart';

/// Estado global: sesión, tema, preferencias y "revisión" de datos (invalida lo cargado tras un cambio).
class AppState extends ChangeNotifier {
  AppState(this._prefs, {ApiClient? client}) : api = client ?? ApiClient(_prefs) {
    api.onUnauthorized = () {
      user = null;
      notifyListeners();
    };
    final saved = _prefs.getString('theme');
    themeMode = ThemeMode.values.where((m) => m.name == saved).firstOrNull ?? ThemeMode.system;
    balanceHidden = _prefs.getString('balance_hidden') == '1';
  }

  final SharedPreferences _prefs;
  final ApiClient api;

  User? user;
  bool booting = true;
  ThemeMode themeMode = ThemeMode.system;
  bool balanceHidden = false;

  /// Sube con cada cambio de datos: las pantallas que dependen de ella se recargan.
  int revision = 0;
  bool _ranRecurring = false;

  /// Mensaje para avisos (toasts) emitidos desde el estado; lo conecta la raíz de la app.
  void Function(String message)? onToast;

  Future<void> boot() async {
    if (api.hasSession) {
      try {
        await _loadUser();
      } on ApiError catch (e) {
        if (e.status == 0) rethrow;
      }
    }
    booting = false;
    notifyListeners();
  }

  Future<void> _loadUser() async {
    user = User.fromJson(await api.get('/auth/me') as Map<String, dynamic>);
  }

  void invalidate() {
    revision++;
    notifyListeners();
  }

  Future<void> login(String email, String password, {bool remember = true}) async {
    await api.saveTokens(
      await api.post('/auth/login', body: {'email': email, 'password': password}, auth: false) as Map<String, dynamic>,
      remember: remember,
    );
    await _loadUser();
    notifyListeners();
    runDueRecurring();
  }

  Future<void> register(String name, String email, String password) async {
    await api.post('/auth/register', body: {'email': email, 'password': password, 'full_name': name}, auth: false);
    await login(email, password);
  }

  /// Registra los movimientos recurrentes vencidos (una vez por sesión) y refresca lo derivado.
  Future<void> runDueRecurring() async {
    if (_ranRecurring || user == null) return;
    _ranRecurring = true;
    try {
      final res = await api.call('POST', '/recurring/run', query: {'today': todayISO()}) as Map<String, dynamic>;
      final created = res['created'] as int;
      if (created > 0) {
        onToast?.call(created == 1 ? 'Se registró 1 movimiento recurrente' : 'Se registraron $created movimientos recurrentes');
        invalidate();
      }
    } catch (_) {
      // Es oportunista: si falla no se molesta al usuario.
    }
  }

  Future<void> logout() async {
    await api.clearTokens();
    user = null;
    _ranRecurring = false;
    revision++;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    user = User.fromJson(await api.patch('/auth/me', body: {'full_name': name}) as Map<String, dynamic>);
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    themeMode = mode;
    _prefs.setString('theme', mode.name);
    notifyListeners();
  }

  void cycleTheme() => setTheme(switch (themeMode) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  });

  void toggleBalanceHidden() {
    balanceHidden = !balanceHidden;
    _prefs.setString('balance_hidden', balanceHidden ? '1' : '0');
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppContext on BuildContext {
  AppState get app => AppScope.of(this);
}
