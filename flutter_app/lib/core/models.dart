/// Modelos de la API. Los montos llegan como cadenas decimales: se conservan tal cual
/// y solo se convierten a `double` para mostrarlos.
double money(Object? v) => double.tryParse('$v') ?? 0;

class Account {
  Account.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name'],
      type = j['type'],
      currency = j['currency'],
      archived = j['archived'],
      balance = money(j['balance']);
  final String id, name, type, currency;
  final bool archived;
  final double balance;
}

class Category {
  Category.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name'],
      kind = j['kind'];
  final String id, name, kind;
}

class Transaction {
  Transaction.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      type = j['type'],
      accountId = j['account_id'],
      transferAccountId = j['transfer_account_id'],
      categoryId = j['category_id'],
      amount = money(j['amount']),
      description = j['description'] ?? '',
      occurredOn = DateTime.parse(j['occurred_on']);
  final String id, type, accountId, description;
  final String? transferAccountId, categoryId;
  final double amount;
  final DateTime occurredOn;
}

class Budget {
  Budget.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      categoryId = j['category_id'],
      amount = money(j['amount']),
      spent = money(j['spent']),
      remaining = money(j['remaining']);
  final String id, categoryId;
  final double amount, spent, remaining;
}

class Goal {
  Goal.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name'],
      currency = j['currency'],
      target = money(j['target_amount']),
      saved = money(j['saved']),
      remaining = money(j['remaining']),
      achieved = j['achieved'],
      deadline = j['deadline'] == null ? null : DateTime.parse(j['deadline']);
  final String id, name, currency;
  final double target, saved, remaining;
  final bool achieved;
  final DateTime? deadline;
}

class Summary {
  Summary.fromJson(Map<String, dynamic> j)
    : month = DateTime.parse(j['month']),
      currency = j['currency'],
      currencies = [for (final c in j['currencies']) c as String],
      income = money(j['income']),
      expense = money(j['expense']),
      net = money(j['net']),
      byCategory = [
        for (final c in j['expense_by_category'])
          (categoryId: c['category_id'] as String?, total: money(c['total'])),
      ],
      trend = [
        for (final m in j['trend'])
          (
            month: DateTime.parse(m['month']),
            income: money(m['income']),
            expense: money(m['expense']),
          ),
      ];
  final DateTime month;
  final String? currency;
  final List<String> currencies;
  final double income, expense, net;
  final List<({String? categoryId, double total})> byCategory;
  final List<({DateTime month, double income, double expense})> trend;
}

class User {
  User.fromJson(Map<String, dynamic> j)
    : email = j['email'],
      fullName = j['full_name'];
  final String email, fullName;
}
