import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'accounts_screen.dart';
import 'budgets_screen.dart';
import 'goals_screen.dart';
import 'profile_screen.dart';
import 'summary_screen.dart';
import 'transactions_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _items = [
    (
      icon: Icons.dashboard_outlined,
      selected: Icons.dashboard,
      label: 'Resumen',
    ),
    (
      icon: Icons.receipt_long_outlined,
      selected: Icons.receipt_long,
      label: 'Movimientos',
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      selected: Icons.account_balance_wallet,
      label: 'Cuentas',
    ),
    (
      icon: Icons.pie_chart_outline,
      selected: Icons.pie_chart,
      label: 'Presupuestos',
    ),
    (icon: Icons.flag_outlined, selected: Icons.flag, label: 'Metas'),
  ];

  static const _screens = <Widget>[
    SummaryScreen(),
    TransactionsScreen(),
    AccountsScreen(),
    BudgetsScreen(),
    GoalsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: IndexedStack(index: _index, children: _screens),
      ),
    );
    final profile = IconButton(
      tooltip: 'Perfil',
      icon: const Icon(Icons.account_circle_outlined),
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Alvea',
          style: TextStyle(color: c.mint, fontWeight: FontWeight.w800),
        ),
        actions: [profile],
      ),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIndex: _index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: [
                      for (final i in _items)
                        NavigationRailDestination(
                          icon: Icon(i.icon),
                          selectedIcon: Icon(i.selected),
                          label: Text(i.label),
                        ),
                    ],
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              backgroundColor: c.surface.withValues(alpha: 0.9),
              indicatorColor: c.mintSoft,
              labelTextStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final i in _items)
                  NavigationDestination(
                    icon: Icon(i.icon),
                    selectedIcon: Icon(i.selected, color: c.mint),
                    label: i.label,
                  ),
              ],
            ),
    );
  }
}
