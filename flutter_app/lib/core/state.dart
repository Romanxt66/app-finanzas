import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/accent.dart';

import 'api.dart';
import 'app_lock.dart';
import 'format.dart';
import 'models.dart';
import 'notices.dart';
import 'pending.dart';
import 'reminder_center.dart';
import 'native_app.dart';
import 'widget_sync.dart';

/// Estado global: sesión, tema, preferencias y "revisión" de datos (invalida lo cargado tras un cambio).
class AppState extends ChangeNotifier {
  AppState(this._prefs, {ApiClient? client, this.quiet = false}) : api = client ?? ApiClient(_prefs) {
    api.onUnauthorized = () {
      user = null;
      _prefs.remove(_userCacheKey);
      notifyListeners();
    };
    final saved = _prefs.getString('theme');
    themeMode = ThemeMode.values.where((m) => m.name == saved).firstOrNull ?? ThemeMode.system;
    balanceHidden = _prefs.getString('balance_hidden') == '1';
    reduceMotion = _prefs.getString('reduce_motion') == '1';
    accent = accentById(_prefs.getString('accent'));
    glow = glowById(_prefs.getString('glow'));
  }

  final SharedPreferences _prefs;
  final ApiClient api;

  /// Recuadro rápido (otra actividad con su propio motor): sin avisos, recordatorios ni widgets,
  /// que ya los lleva la app principal.
  final bool quiet;

  /// Avisos (cobros próximos, presupuestos, Sala de espera); se recargan con cada cambio de datos.
  late final NoticeCenter notices = NoticeCenter(_prefs, api);

  /// Movimientos guardados sin conexión desde el recuadro rápido.
  late final PendingQueue pending = PendingQueue(_prefs, api);

  /// Widgets del escritorio de Android (imágenes al día con los datos).
  late final WidgetSync widgets = WidgetSync(this);

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

  /// Color de acento y luz del fondo elegidos en Perfil → Apariencia (de este dispositivo).
  AccentChoice accent = fuchsiaAccent;
  GlowLevel glow = GlowLevel.normal;

  /// Sube con cada cambio de datos: las pantallas que dependen de ella se recargan.
  int revision = 0;
  bool _ranRecurring = false;

  /// Mensaje para avisos (toasts) emitidos desde el estado; lo conecta la raíz de la app.
  void Function(String message)? onToast;

  /// Aviso con botón (p. ej. «Deshacer» tras eliminar).
  void Function(String message, String actionLabel, VoidCallback onAction)? onToastAction;

  static const _userCacheKey = 'user_cache';

  Future<void> boot() async {
    // Sesión guardada: se entra al momento con el último usuario conocido y se confirma con el
    // servidor en segundo plano (si la sesión ya no vale, el 401 la cierra como siempre)
    final cached = api.hasSession ? _prefs.getString(_userCacheKey) : null;
    if (cached != null) {
      try {
        user = User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        booting = false;
        notifyListeners();
        if (!quiet) {
          notices.load();
          reminders.refresh();
        }
        _loadUser().then((_) => notifyListeners(), onError: (Object _) {});
        return;
      } catch (_) {
        user = null; // caché ilegible: se sigue por el camino normal
      }
    }
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
    final me = await api.get('/auth/me') as Map<String, dynamic>;
    user = User.fromJson(me);
    // Solo si la sesión se guarda en el dispositivo; sin «mantener sesión» no queda nada en disco
    if (api.remembered) {
      await _prefs.setString(_userCacheKey, jsonEncode(me));
    } else {
      await _prefs.remove(_userCacheKey);
    }
    if (!quiet) {
      notices.load();
      reminders.refresh();
      widgets.schedule();
    }
    _sendPending();
  }

  /// Envía lo que el recuadro rápido guardó sin conexión.
  Future<void> _sendPending() async {
    if (pending.length == 0) return;
    final sent = await pending.flush();
    if (sent > 0) {
      onToast?.call(sent == 1 ? 'Se guardó 1 movimiento que estaba pendiente' : 'Se guardaron $sent movimientos pendientes');
      invalidate();
    }
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
      widgets.schedule();
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
    await _prefs.remove(_userCacheKey);
    user = null;
    notices.clear();
    await reminders.clear();
    await NativeApp.clearWidgets();
    await lock.disable(); // el PIN es de esta sesión: otra persona que entre no lo hereda
    _ranRecurring = false;
    revision++;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final me = await api.patch('/auth/me', body: {'full_name': name}) as Map<String, dynamic>;
    user = User.fromJson(me);
    if (api.remembered) await _prefs.setString(_userCacheKey, jsonEncode(me));
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

  void setAccent(AccentChoice value) {
    accent = value;
    _prefs.setString('accent', value.id);
    notifyListeners();
    widgets.schedule();
  }

  void setGlow(GlowLevel value) {
    glow = value;
    _prefs.setString('glow', value.name);
    notifyListeners();
  }

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
