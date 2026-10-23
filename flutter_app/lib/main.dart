import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/state.dart';
import 'screens/auth_screen.dart';
import 'screens/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final state = AppState(await SharedPreferences.getInstance());
  runApp(AlveaApp(state: state));
}

class AlveaApp extends StatefulWidget {
  const AlveaApp({super.key, required this.state});
  final AppState state;

  @override
  State<AlveaApp> createState() => _AlveaAppState();
}

class _AlveaAppState extends State<AlveaApp> {
  Object? _bootError;

  @override
  void initState() {
    super.initState();
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
      builder: (context, _) => MaterialApp(
        title: 'Alvea',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: widget.state.themeMode,
        builder: (context, child) => Backdrop(child: child!),
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            if (_bootError != null) {
              return Scaffold(
                body: Center(
                  child: ErrorState(
                    _bootError is ApiError
                        ? _bootError!
                        : ApiError(0, 'network', networkMessage),
                    onRetry: _boot,
                  ),
                ),
              );
            }
            if (widget.state.booting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return widget.state.user == null
                ? const Scaffold(body: AuthScreen())
                : const Shell();
          },
        ),
      ),
    ),
  );
}
