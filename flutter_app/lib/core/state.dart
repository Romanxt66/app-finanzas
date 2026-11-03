import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'app_lock.dart';
import 'format.dart';
import 'models.dart';
import 'notices.dart';
import 'reminder_center.dart';

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
    reduceMotion = _prefs.getString('reduce_motion') == '1';
  }

  final SharedPreferences _prefs;
  final ApiClient api;

  /// Avisos (cobros próximos, presupuestos, Sala de espera); se recargan con cada cambio de datos.
  late final NoticeCenter notices = NoticeCenter(_prefs, api);

  /// Recordatorios de cobro (avisos del sistema en Android, banner y hoja en la app).
  late final ReminderCenter reminders = ReminderCenter(_prefs, api);

  /// Bloqueo con PIN de este dispositivo.
  late final AppLock lock = AppLock(_prefs)..onTooManyAttempts = _lockedOut;

  Future<void> _lockedOut() async {
    await logout();
    onToast?.call('Demasiados intentos con el PIN: inicia sesión de nuevo');
  }

  User? user;
  bool booting = true;
  ThemeMode themeMode = ThemeMode.system;
  bool balanceHidden = false;

  /// Reducir animaciones aunque el sistema no lo pida (se suma a «reducir movimiento» del sistema).
  bool reduceMotion = false;

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
    notices.load();
    reminders.refresh();
  }

  /// Vuelve a leer el usuario (p. ej. tras activar la verificación en dos pasos).
  Future<void> reloadUser() async {
    await _loadUser();
    notifyListeners();
  }

  void invalidate() {
    revision++;
    notifyListeners();
    if (user != null) {
      notices.load();
      reminders.refresh();
    }
  }

  /// [otp]: código de la app de autenticación o de recuperación, si la cuenta lo pide
  /// (el servidor responde `otp_required` cuando falta).
  Future<void> login(String email, String password, {bool remember = true, String? otp}) async {
    await api.saveTokens(
      await api.post('/auth/login', body: {'email': email, 'password': password, 'otp': ?otp}, auth: false) as Map<String, dynamic>,
      remember: remember,
    );
    lock.unlockAfterLogin(); // p. ej. la sesión caducó con la app bloqueada
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
      // Los de hoy que se van a registrar se muestran luego como «pagados» en la hoja de cobros
      final due = await reminders.dueToday();
      final res = await api.call('POST', '/recurring/run', query: {'today': todayISO()}) as Map<String, dynamic>;
      final created = res['created'] as int;
      if (created > 0) {
        await reminders.markRegistered(due);
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
    notices.clear();
    await reminders.clear();
    await lock.disable(); // el PIN es de esta sesión: otra persona que entre no lo hereda
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

  void setReduceMotion(bool value) {
    reduceMotion = value;
    _prefs.setString('reduce_motion', value ? '1' : '0');
    notifyListeners();
  }

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
