import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/error_report.dart';
import 'core/state.dart';
import 'screens/accounts.dart';
import 'screens/auth_screens.dart';
import 'screens/budgets.dart';
import 'screens/categories.dart';
import 'screens/dashboard.dart';
import 'screens/goals.dart';
import 'screens/import_screen.dart';
import 'screens/layout.dart';
import 'screens/lock_screen.dart';
import 'screens/more.dart';
import 'screens/profile.dart';
import 'screens/recurring.dart';
import 'screens/subscriptions.dart';
import 'screens/transactions.dart';
import 'screens/waiting_room.dart';
import 'ui/buttons.dart';
import 'ui/dialogs.dart';
import 'ui/glass.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // URLs como la web React (/transactions), no /#/transactions
  await initializeDateFormatting('es');
  final state = AppState(await SharedPreferences.getInstance());
  var failed = false;
  final reporter = ErrorReporter(route: () => Uri.base.path);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    failed = true;
    if (kReleaseMode) reporter.report(details.exception, details.stack);
  };
  // Errores asíncronos que nadie capturó (futuros, callbacks del navegador…)
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kReleaseMode) reporter.report(error, stack);
    return false; // además, que se registren como siempre en la consola
  };
  runApp(AlveaApp(state: state, didFail: () => failed));
}

class AlveaApp extends StatefulWidget {
  const AlveaApp({super.key, required this.state, this.didFail});
  final AppState state;
  final bool Function()? didFail;

  @override
  State<AlveaApp> createState() => _AlveaAppState();
}

class _AlveaAppState extends State<AlveaApp> {
  final _toasts = ToastController();
  late final GoRouter _router = _buildRouter(widget.state);
  Object? _bootError;

  @override
  void initState() {
    super.initState();
    widget.state.onToast = _toasts.success;
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _bootError = null);
    try {
      await widget.state.boot();
    } catch (e) {
      if (mounted) setState(() => _bootError = e);
    }
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: widget.state,
    child: ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => MaterialApp.router(
        title: 'Alvea',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: widget.state.themeMode,
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
        builder: (context, child) {
          Widget body = child ?? const SizedBox.shrink();
          if (_bootError != null) {
            body = Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(space5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _bootError is ApiError ? (_bootError as ApiError).message : networkMessage,
                        textAlign: TextAlign.center,
                        style: CrText.body(context.c.inkMuted),
                      ),
                      const SizedBox(height: space4),
                      CrButton(label: 'Reintentar', onPressed: _boot),
                    ],
                  ),
                ),
              ),
            );
          } else if (widget.state.booting) {
            body = Center(
              child: Semantics(
                liveRegion: true,
                label: 'Cargando…',
                child: Text('Cargando…', style: CrText.body(context.c.inkMuted)),
              ),
            );
          }
          // Bloqueo con PIN: la app sigue montada debajo (no pierde lo escrito), pero oculta e inerte
          final lock = widget.state.lock;
          body = ListenableBuilder(
            listenable: lock,
            child: body,
            builder: (context, app) {
              final locked = lock.locked && widget.state.user != null;
              return Stack(
                children: [
                  Visibility(visible: !locked, maintainState: true, child: app!),
                  if (locked) const Positioned.fill(child: LockScreen()),
                ],
              );
            },
          );
          // «Reducir animaciones» de la app se suma al ajuste del sistema (prefers-reduced-motion)
          if (widget.state.reduceMotion) {
            final mq = MediaQuery.of(context);
            body = MediaQuery(data: mq.copyWith(disableAnimations: true), child: body);
          }
          return DefaultTextStyle.merge(
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()], fontFamilyFallback: ['SymbolsFallback']),
            child: CrBackdrop(
              child: ToastHost(controller: _toasts, child: body),
            ),
          );
        },
      ),
    ),
  );
}

GoRouter _buildRouter(AppState app) {
  Page<void> page(Widget child, GoRouterState s) => NoTransitionPage<void>(key: s.pageKey, child: child);
  return GoRouter(
    refreshListenable: app,
    redirect: (context, state) {
      if (app.booting) return null;
      final authed = app.user != null;
      final onAuth = state.uri.path == '/login' || state.uri.path == '/register';
      if (!authed && !onAuth) return '/login';
      if (authed && onAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', pageBuilder: (c, s) => page(const LoginScreen(), s)),
      GoRoute(path: '/register', pageBuilder: (c, s) => page(const RegisterScreen(), s)),
      ShellRoute(
        builder: (context, state, child) => AppLayout(child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (c, s) => page(const DashboardScreen(), s)),
          GoRoute(path: '/transactions', pageBuilder: (c, s) => page(const TransactionsScreen(), s)),
          GoRoute(path: '/accounts', pageBuilder: (c, s) => page(const AccountsScreen(), s)),
          GoRoute(path: '/categories', pageBuilder: (c, s) => page(const CategoriesScreen(), s)),
          GoRoute(path: '/budgets', pageBuilder: (c, s) => page(const BudgetsScreen(), s)),
          GoRoute(path: '/goals', pageBuilder: (c, s) => page(const GoalsScreen(), s)),
          GoRoute(path: '/recurring', pageBuilder: (c, s) => page(const RecurringScreen(), s)),
          GoRoute(path: '/subscriptions', pageBuilder: (c, s) => page(const SubscriptionsScreen(), s)),
          GoRoute(path: '/import', pageBuilder: (c, s) => page(const ImportScreen(), s)),
          GoRoute(path: '/profile', pageBuilder: (c, s) => page(const ProfileScreen(), s)),
          GoRoute(path: '/waiting', pageBuilder: (c, s) => page(const WaitingRoomScreen(), s)),
          GoRoute(path: '/more', pageBuilder: (c, s) => page(const MoreScreen(), s)),
        ],
      ),
    ],
  );
}
