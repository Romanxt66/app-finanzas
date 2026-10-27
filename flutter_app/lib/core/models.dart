/// Modelos de la API. Los montos llegan como cadenas decimales: solo se convierten a `double` para mostrarlos.
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
  Category.fromJson(Map<String, dynamic> j) : id = j['id'], name = j['name'], kind = j['kind'];
  final String id, name, kind;
}

class Transaction {
  Transaction.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      type = j['type'],
      accountId = j['account_id'],
      transferAccountId = j['transfer_account_id'],
      categoryId = j['category_id'],
      amountRaw = '${j['amount']}',
      amount = money(j['amount']),
      description = j['description'] ?? '',
      occurredOn = j['occurred_on'],
      mood = j['mood'];
  final String id, type, accountId, description, occurredOn, amountRaw;
  final String? transferAccountId, categoryId;

  /// Ánimo al gastar (`happy`, `calm`, `stressed`, `sad`, `bored`) o null.
  final String? mood;
  final double amount;
}

class TransactionPage {
  TransactionPage.fromJson(Map<String, dynamic> j) : items = [for (final t in j['items']) Transaction.fromJson(t)], total = j['total'];
  final List<Transaction> items;
  final int total;
}

class Budget {
  Budget.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      categoryId = j['category_id'],
      amount = money(j['amount']),
      spent = money(j['spent']);
  final String id, categoryId;
  final double amount, spent;
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
      deadline = j['deadline'];
  final String id, name, currency;
  final double target, saved, remaining;
  final bool achieved;
  final String? deadline;
}

class Recurring {
  Recurring.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      type = j['type'],
      accountId = j['account_id'],
      categoryId = j['category_id'],
      amount = money(j['amount']),
      description = j['description'] ?? '',
      frequency = j['frequency'],
      nextDate = j['next_date'],
      active = j['active'];
  final String id, type, accountId, description, frequency, nextDate;
  final String? categoryId;
  final double amount;
  final bool active;
}

class Summary {
  Summary.fromJson(Map<String, dynamic> j)
    : month = j['month'],
      currency = j['currency'],
      currencies = [for (final c in j['currencies']) c as String],
      income = money(j['income']),
      expense = money(j['expense']),
      byCategory = [for (final c in j['expense_by_category']) (categoryId: c['category_id'] as String?, total: money(c['total']))],
      trend = [for (final m in j['trend']) (month: m['month'] as String, income: money(m['income']), expense: money(m['expense']))];
  final String month;
  final String? currency;
  final List<String> currencies;
  final double income, expense;
  final List<({String? categoryId, double total})> byCategory;
  final List<({String month, double income, double expense})> trend;
}

class User {
  User.fromJson(Map<String, dynamic> j) : email = j['email'], fullName = j['full_name'];
  final String email, fullName;
}

class LifeProfile {
  LifeProfile.fromJson(Map<String, dynamic> j)
    : monthlyNetIncome = '${j['monthly_net_income']}',
      weeklyHours = '${j['weekly_hours']}',
      hourlyRate = money(j['hourly_rate']);
  final String monthlyNetIncome, weeklyHours;
  final double hourlyRate;
}

class LifeMonth {
  LifeMonth.fromJson(Map<String, dynamic> j)
    : totalHours = money(j['total_hours']),
      byCategory = [for (final c in j['by_category']) (categoryId: c['category_id'] as String?, hours: money(c['hours']))];
  final double totalHours;
  final List<({String? categoryId, double hours})> byCategory;
}

class Subscription {
  Subscription.fromJson(Map<String, dynamic> j)
    : name = j['name'],
      currency = j['currency'],
      cadence = j['cadence'],
      lastAmount = money(j['last_amount']),
      nextExpected = j['next_expected'],
      monthlyCost = money(j['monthly_cost']),
      tracked = j['tracked'];
  final String name, currency, cadence, nextExpected;
  final double lastAmount, monthlyCost;
  final bool tracked;
}

class GhostAlert {
  GhostAlert.fromJson(Map<String, dynamic> j)
    : kind = j['kind'],
      name = j['name'],
      currency = j['currency'],
      date = j['date'],
      amount = money(j['amount']),
      previousAmount = j['previous_amount'] == null ? null : money(j['previous_amount']),
      changePercent = j['change_percent'] == null ? null : money(j['change_percent']);
  final String kind, name, currency, date;
  final double amount;
  final double? previousAmount, changePercent;
}

class GhostReport {
  GhostReport.fromJson(Map<String, dynamic> j)
    : subscriptions = [for (final s in j['subscriptions']) Subscription.fromJson(s)],
      alerts = [for (final a in j['alerts']) GhostAlert.fromJson(a)],
      untrackedMonthly = [for (final t in j['untracked_monthly']) (currency: t['currency'] as String, total: money(t['total']))];
  final List<Subscription> subscriptions;
  final List<GhostAlert> alerts;
  final List<({String currency, double total})> untrackedMonthly;
}

class DailyAllowance {
  DailyAllowance.fromJson(Map<String, dynamic> j)
    : currency = j['currency'],
      basis = j['basis'],
      pendingCommitted = money(j['pending_committed']),
      daysRemaining = j['days_remaining'],
      averagePerDay = money(j['average_per_day']),
      allowanceToday = money(j['allowance_today']),
      leftToday = money(j['left_today']),
      spentToday = money(j['spent_today']),
      patternUsed = j['pattern_used'],
      status = j['status'];
  final String currency, basis, status;
  final double pendingCommitted, averagePerDay, allowanceToday, leftToday, spentToday;
  final int daysRemaining;
  final bool patternUsed;
}

class CategorySuggestions {
  CategorySuggestions.fromJson(Map<String, dynamic> j)
    : expense = [for (final s in j['expense']) '$s'],
      income = [for (final s in j['income']) '$s'];
  final List<String> expense, income;
}

class InflationItem {
  InflationItem.fromJson(Map<String, dynamic> j)
    : merchant = j['merchant'],
      category = j['category'],
      basePrice = money(j['base_price']),
      currentPrice = money(j['current_price']),
      changePct = money(j['change_pct']),
      weightPct = money(j['weight_pct']);
  final String merchant;
  final String? category;
  final double basePrice, currentPrice, changePct, weightPct;
}

/// Inflación personal: cuánto se encareció lo que compras (`/personal-inflation`).
class PersonalInflation {
  PersonalInflation.fromJson(Map<String, dynamic> j)
    : currency = j['currency'],
      comparison = j['comparison'],
      indexPct = j['index_pct'] == null ? null : money(j['index_pct']),
      coveragePct = money(j['coverage_pct']),
      matched = j['matched'],
      items = [for (final i in j['items']) InflationItem.fromJson(i)],
      categories = [
        for (final c in j['categories'])
          (category: c['category'] as String?, changePct: money(c['change_pct']), weightPct: money(c['weight_pct'])),
      ];
  final String? currency;

  /// `year` (frente a hace un año), `half_year` (frente a hace seis meses) o null si no hay historial.
  final String? comparison;
  final double? indexPct;
  final double coveragePct;
  final int matched;
  final List<InflationItem> items;
  final List<({String? category, double changePct, double weightPct})> categories;
}

class MoodStat {
  MoodStat.fromJson(Map<String, dynamic> j)
    : mood = j['mood'],
      count = j['count'],
      total = money(j['total']),
      average = money(j['average']),
      sharePct = money(j['share_pct']);
  final String mood;
  final int count;
  final double total, average, sharePct;
}

/// Ánimo del gasto: cuánto y cómo gastas según cómo te sientes (`/spending-mood`).
class MoodReport {
  MoodReport.fromJson(Map<String, dynamic> j)
    : currency = j['currency'],
      expenses = j['expenses'],
      tagged = j['tagged'],
      byMood = [for (final m in j['by_mood']) MoodStat.fromJson(m)],
      highlight = j['highlight'] == null
          ? null
          : (
              mood: j['highlight']['mood'] as String,
              average: money(j['highlight']['average']),
              baseline: money(j['highlight']['baseline']),
              changePct: money(j['highlight']['change_pct']),
              weekday: j['highlight']['top_weekday'] as int,
            );
  final String? currency;
  final int expenses, tagged;
  final List<MoodStat> byMood;
  final ({String mood, double average, double baseline, double changePct, int weekday})? highlight;
}

class WaitingItem {
  WaitingItem.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name'],
      amount = money(j['amount']),
      currency = j['currency'],
      waitHours = j['wait_hours'],
      createdAt = DateTime.parse(j['created_at']),
      readyAt = DateTime.parse(j['ready_at']),
      status = j['status'],
      decidedAt = j['decided_at'] == null ? null : DateTime.parse(j['decided_at']),
      ready = j['ready'];
  final String id, name, currency;
  final double amount;
  final int waitHours;
  final DateTime createdAt, readyAt;

  /// `waiting`, `bought` o `skipped`.
  final String status;
  final DateTime? decidedAt;
  final bool ready;
}

/// Sala de espera: compras aparcadas y lo que no gastaste (`/waiting-room`).
class WaitingRoom {
  WaitingRoom.fromJson(Map<String, dynamic> j)
    : items = [for (final i in j['items']) WaitingItem.fromJson(i)],
      waiting = j['waiting'],
      ready = j['ready'],
      skipped = j['skipped'],
      bought = j['bought'],
      notSpent = [for (final t in j['not_spent']) (currency: t['currency'] as String, total: money(t['total']))];
  final List<WaitingItem> items;
  final int waiting, ready, skipped, bought;
  final List<({String currency, double total})> notSpent;
}
