import 'api.dart';
import 'format.dart';
import 'models.dart';
import 'state.dart';

/// Lecturas de la API (tipadas) y escrituras que invalidan lo cargado.
class Data {
  Data(this.app);
  final AppState app;
  ApiClient get _api => app.api;

  Future<List<Account>> accounts({bool includeArchived = false}) async => [
    for (final a in await _api.get('/accounts', query: {'include_archived': includeArchived}) as List) Account.fromJson(a),
  ];

  Future<List<Category>> categories() async => [for (final c in await _api.get('/categories') as List) Category.fromJson(c)];

  Future<List<String>> currencies() async => [for (final c in await _api.get('/currencies') as List) '$c'];

  Future<CategorySuggestions> categorySuggestions() async =>
      CategorySuggestions.fromJson(await _api.get('/categories/suggestions') as Map<String, dynamic>);

  Future<TransactionPage> transactions(Map<String, Object?> query) async =>
      TransactionPage.fromJson(await _api.get('/transactions', query: query) as Map<String, dynamic>);

  Future<List<Budget>> budgets(String month) async => [
    for (final b in await _api.get('/budgets', query: {'month': month}) as List) Budget.fromJson(b),
  ];

  Future<Summary> summary(String month, String? currency) async =>
      Summary.fromJson(await _api.get('/reports/summary', query: {'month': month, 'currency': currency}) as Map<String, dynamic>);

  Future<List<Goal>> goals() async => [for (final g in await _api.get('/goals') as List) Goal.fromJson(g)];

  Future<List<Recurring>> recurring() async => [for (final r in await _api.get('/recurring') as List) Recurring.fromJson(r)];

  Future<LifeProfile?> lifeProfile() async {
    try {
      return LifeProfile.fromJson(await _api.get('/life-hours/profile') as Map<String, dynamic>);
    } on ApiError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<LifeMonth> lifeMonth(String month) async =>
      LifeMonth.fromJson(await _api.get('/life-hours/summary', query: {'month': month}) as Map<String, dynamic>);

  Future<GhostReport> ghost() async =>
      GhostReport.fromJson(await _api.get('/ghost-subscriptions', query: {'today': todayISO()}) as Map<String, dynamic>);

  Future<DailyAllowance?> allowance() async {
    try {
      return DailyAllowance.fromJson(await _api.get('/daily-allowance', query: {'today': todayISO()}) as Map<String, dynamic>);
    } on ApiError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<PersonalInflation> inflation() async =>
      PersonalInflation.fromJson(await _api.get('/personal-inflation', query: {'today': todayISO()}) as Map<String, dynamic>);

  Future<MoodReport> spendingMood() async =>
      MoodReport.fromJson(await _api.get('/spending-mood', query: {'today': todayISO()}) as Map<String, dynamic>);

  Future<WaitingRoom> waitingRoom() async => WaitingRoom.fromJson(await _api.get('/waiting-room') as Map<String, dynamic>);

  /// Ejecuta una escritura, avisa con un toast y recarga lo cargado.
  Future<T> mutate<T>(Future<T> Function() action, String message) async {
    final result = await action();
    if (message.isNotEmpty) app.onToast?.call(message);
    app.invalidate();
    return result;
  }

  Future<void> post(String path, Object body, String message) => mutate(() => _api.post(path, body: body), message);
  Future<void> patch(String path, Object body, String message) => mutate(() => _api.patch(path, body: body), message);
  Future<void> delete(String path, String message) => mutate(() => _api.delete(path), message);
  Future<void> put(String path, Object body, String message) => mutate(() => _api.call('PUT', path, body: body), message);
}

extension DataContext on AppState {
  Data get data => Data(this);
}
