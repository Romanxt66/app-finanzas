import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// Estado global: sesión, tema y datos de referencia (cuentas y categorías).
class AppState extends ChangeNotifier {
  AppState(this._prefs) : api = ApiClient(_prefs) {
    api.onUnauthorized = () {
      user = null;
      notifyListeners();
    };
    final saved = _prefs.getString('theme');
    themeMode =
        ThemeMode.values.where((m) => m.name == saved).firstOrNull ??
        ThemeMode.system;
  }

  final SharedPreferences _prefs;
  final ApiClient api;

  User? user;
  bool booting = true;
  ThemeMode themeMode = ThemeMode.system;
  List<Account> accounts = [];
  List<Category> categories = [];
  List<String> currencies = ['COP'];

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
    await loadReference();
  }

  Future<void> loadReference() async {
    final results = await Future.wait([
      api.get('/accounts'),
      api.get('/categories'),
      api.get('/currencies'),
    ]);
    accounts = [for (final a in results[0] as List) Account.fromJson(a)];
    categories = [for (final c in results[1] as List) Category.fromJson(c)];
    final codes = [for (final c in results[2] as List) c as String];
    if (codes.isNotEmpty) currencies = codes;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await api.saveTokens(
      await api.post(
        '/auth/login',
        body: {'email': email, 'password': password},
        auth: false,
      ),
    );
    await _loadUser();
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    await api.post(
      '/auth/register',
      body: {'email': email, 'password': password, 'full_name': name},
      auth: false,
    );
    await login(email, password);
  }

  Future<void> logout() async {
    await api.clearTokens();
    user = null;
    accounts = [];
    categories = [];
    notifyListeners();
  }

  Future<void> logoutEverywhere() async {
    await api.post('/auth/logout-all');
    await logout();
  }

  void setTheme(ThemeMode mode) {
    themeMode = mode;
    _prefs.setString('theme', mode.name);
    notifyListeners();
  }

  String categoryName(String? id) => id == null
      ? 'Sin categoría'
      : categories.where((c) => c.id == id).firstOrNull?.name ??
            'Sin categoría';

  Account? account(String id) => accounts.where((a) => a.id == id).firstOrNull;
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppContext on BuildContext {
  AppState get app => AppScope.of(this);
}
