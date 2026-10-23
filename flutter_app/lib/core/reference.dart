import 'package:flutter/material.dart';

import '../ui/query.dart';
import 'data.dart';
import 'models.dart';
import 'state.dart';

/// Datos de referencia compartidos por casi todas las pantallas (cuentas, categorías, monedas).
class RefData {
  const RefData({
    this.accounts = const [],
    this.allAccounts = const [],
    this.categories = const [],
    this.currencies = const [],
    this.hourlyRate,
    this.loaded = false,
  });
  final List<Account> accounts;
  final List<Account> allAccounts;
  final List<Category> categories;
  final List<String> currencies;

  /// Valor de la hora del usuario (horas de vida); null si no lo configuró.
  final double? hourlyRate;
  final bool loaded;

  String categoryName(String? id) =>
      id == null ? 'Sin categoría' : categories.where((c) => c.id == id).firstOrNull?.name ?? 'Sin categoría';
  Account? account(String id) => allAccounts.where((a) => a.id == id).firstOrNull;
  String? currencyOf(String accountId) => account(accountId)?.currency;

  /// Moneda para totales agregados: la de la primera cuenta activa.
  String? get displayCurrency => accounts.firstOrNull?.currency;
}

class RefScope extends InheritedWidget {
  const RefScope({super.key, required this.ref, required super.child});
  final RefData ref;

  static RefData of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RefScope>()?.ref ?? const RefData();

  @override
  bool updateShouldNotify(RefScope old) => old.ref != ref;
}

extension RefContext on BuildContext {
  RefData get ref => RefScope.of(this);
}

/// Carga y renueva los datos de referencia mientras hay sesión.
class RefLoader extends StatelessWidget {
  const RefLoader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final data = app.data;
    return Query<RefData>(
      load: () async {
        final r = await Future.wait([data.accounts(includeArchived: true), data.categories(), data.currencies(), data.lifeProfile()]);
        final all = r[0] as List<Account>;
        return RefData(
          accounts: all.where((a) => !a.archived).toList(),
          allAccounts: all,
          categories: r[1] as List<Category>,
          currencies: r[2] as List<String>,
          hourlyRate: (r[3] as LifeProfile?)?.hourlyRate,
          loaded: true,
        );
      },
      builder: (context, q) => RefScope(ref: q.data ?? const RefData(), child: child),
    );
  }
}
