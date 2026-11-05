import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/data.dart';
import 'core/format.dart';
import 'core/models.dart';
import 'core/state.dart';
import 'screens/insights.dart' show FinanceMood;
import 'screens/lock_screen.dart';
import 'ui/dialogs.dart';
import 'ui/icons.dart';
import 'ui/mood_face.dart';
import 'ui/theme.dart';

// Recuadro rápido: se abre desde el botón del panel rápido o desde el widget «Gasto rápido», encima
// de lo que haya en pantalla (actividad transparente con su propio motor de Flutter). Anota un
// gasto o un ingreso en tres toques: monto, categoría y guardar.

/// Canal con la parte nativa (el mismo nombre en la actividad principal y en la del recuadro).
const appChannel = MethodChannel('click.softlane.alvea/app');

Future<void> runQuickAdd() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs, quiet: true);
  String type = 'expense';
  try {
    type = await appChannel.invokeMethod<String>('quickAddType') ?? 'expense';
  } catch (_) {}
  unawaited(state.boot().catchError((Object _) {}));
  runApp(QuickAddApp(state: state, type: type));
}

Future<void> _close() async {
  try {
    await appChannel.invokeMethod<void>('finish');
  } catch (_) {
    await SystemNavigator.pop();
  }
}

Future<void> _openApp([String route = '/']) async {
  try {
    await appChannel.invokeMethod<void>('openApp', route);
  } catch (_) {
    await _close();
  }
}

class QuickAddApp extends StatelessWidget {
  const QuickAddApp({super.key, required this.state, required this.type});
  final AppState state;
  final String type;

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Alvea',
        // El recuadro es siempre oscuro: va sobre cualquier fondo (escritorio, otra app)
        theme: buildTheme(Brightness.dark, accent: state.accent, glow: state.glow),
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        color: Colors.transparent,
        builder: (context, child) => LockGate(state: state, child: child ?? const SizedBox.shrink()),
        home: ToastHost(
          controller: ToastController(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: QuickAddSheet(type: type),
          ),
        ),
      ),
    ),
  );
}

/// Uso de categorías por franja del día (las más usadas a esta hora van primero).
class CategoryUsage {
  CategoryUsage(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'quick_usage';

  static int bucket(DateTime t) => t.hour < 6 ? 0 : (t.hour < 12 ? 1 : (t.hour < 18 ? 2 : 3));

  Map<String, int> _read() {
    try {
      return Map<String, int>.from(jsonDecode(_prefs.getString(_key) ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  int count(String categoryId, DateTime now) => _read()['${bucket(now)}|$categoryId'] ?? 0;

  Future<void> add(String categoryId, DateTime now) {
    final m = _read();
    final k = '${bucket(now)}|$categoryId';
    m[k] = (m[k] ?? 0) + 1;
    return _prefs.setString(_key, jsonEncode(m));
  }

  /// [categories] ordenadas por uso a esta hora (sin perder el orden original entre iguales).
  List<Category> sort(List<Category> categories, DateTime now) {
    final indexed = categories.indexed.toList()
      ..sort((a, b) {
        final byUse = count(b.$2.id, now).compareTo(count(a.$2.id, now));
        return byUse != 0 ? byUse : a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }
}

enum _Step { amount, details, done }

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, required this.type, this.onClose});
  final String type;

  /// Dentro de la app se cierra como un diálogo; en el recuadro del sistema, cerrando la actividad.
  final VoidCallback? onClose;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  late String _type = widget.type == 'income' ? 'income' : 'expense';
  String _digits = '';
  _Step _step = _Step.amount;
  List<Category> _categories = const [];
  List<Account> _accounts = const [];
  String? _category;
  String? _account;
  bool _busy = false;
  bool _queued = false;
  String? _savedId;
  Object? _error;
  Timer? _autoClose;
  late final SharedPreferences _prefs;
  late final CategoryUsage _usage;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  Future<void> _load() async {
    final app = context.app;
    _prefs = await SharedPreferences.getInstance();
    _usage = CategoryUsage(_prefs);
    try {
      final r = await Future.wait([app.data.categories(), app.data.accounts()]);
      if (!mounted) return;
      setState(() {
        _categories = r[0] as List<Category>;
        _accounts = r[1] as List<Account>;
        final last = _prefs.getString('quick_account');
        _account = _accounts.any((a) => a.id == last) ? last : _accounts.firstOrNull?.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  void _dismiss() {
    _autoClose?.cancel();
    final close = widget.onClose;
    if (close != null) {
      if (mounted) close();
    } else {
      _close();
    }
  }

  double get _amount => double.tryParse(_digits) ?? 0;

  List<Category> get _kindCategories => _usage.sort(_categories.where((c) => c.kind == _type).toList(), DateTime.now());

  Account? get _selectedAccount => _accounts.where((a) => a.id == _account).firstOrNull;

  void _press(String key) {
    setState(() {
      if (key == '⌫') {
        _digits = _digits.isEmpty ? '' : _digits.substring(0, _digits.length - 1);
      } else if (key == '000') {
        if (_digits.isNotEmpty && _digits.length <= 9) _digits += '000';
      } else if (_digits.length < 12) {
        _digits = (_digits == '0' ? '' : _digits) + key;
      }
    });
  }

  Future<void> _save() async {
    final account = _account;
    if (account == null || _amount <= 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = context.app;
    final body = {
      'type': _type,
      'account_id': account,
      'category_id': _category,
      'amount': _digits,
      'description': '',
      'occurred_on': todayISO(),
    };
    try {
      final res = await app.api.post('/transactions', body: body) as Map<String, dynamic>?;
      _savedId = res?['id'] as String?;
      _queued = false;
    } on ApiError catch (e) {
      if (e.status != 0) {
        if (mounted) {
          setState(() {
            _error = e;
            _busy = false;
          });
        }
        return;
      }
      // Sin conexión: queda guardado en el teléfono y se envía al abrir la app con conexión
      await app.pending.add(body);
      _queued = true;
    }
    app.invalidate();
    await _prefs.setString('quick_account', account);
    if (_category != null) await _usage.add(_category!, DateTime.now());
    try {
      await appChannel.invokeMethod<void>('updateWidgets');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _Step.done;
    });
    _autoClose = Timer(const Duration(seconds: 3), _dismiss);
  }

  Future<void> _undo() async {
    _autoClose?.cancel();
    final app = context.app;
    if (_savedId != null) {
      try {
        await app.api.delete('/transactions/$_savedId');
        await appChannel.invokeMethod<void>('updateWidgets');
      } catch (_) {}
    }
    _again();
  }

  void _again() {
    _autoClose?.cancel();
    setState(() {
      _digits = '';
      _category = null;
      _savedId = null;
      _queued = false;
      _step = _Step.amount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final signedIn = app.user != null;
    return Stack(
      children: [
        // Tocar fuera cierra el recuadro
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: const ColoredBox(color: Color(0x9E050505)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.viewInsetsOf(context).bottom),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _Panel(
                  accent: _step == _Step.done || _type == 'income' ? const Color(0xFFFFFFFF) : _white,
                  child: AnimatedSize(
                    duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: !signedIn && !app.booting
                        ? _signedOut()
                        : switch (_step) {
                            _Step.amount => _amountStep(),
                            _Step.details => _detailsStep(),
                            _Step.done => _doneStep(),
                          },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _signedOut() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Inicia sesión en Alvea', style: CrText.title(const Color(0xFFF5F5F5))),
      const SizedBox(height: 6),
      Text('Para anotar desde aquí, entra primero en la app.', style: CrText.label(const Color(0xFFD4D4D4))),
      const SizedBox(height: 16),
      _NeonButton(label: 'Abrir Alvea', onPressed: () => _openApp('/login')),
    ],
  );

  Widget _header() {
    const ink = Color(0xFFF5F5F5);
    return Row(
      children: [
        Expanded(child: Text('Nuevo movimiento', style: CrText.label(const Color(0xFFD4D4D4)))),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (t, label) in const [('expense', 'Gasto'), ('income', 'Ingreso')])
                Semantics(
                  button: true,
                  selected: _type == t,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _type = t;
                      _category = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: _type == t
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: t == 'income'
                                    ? const [Color(0xFFFFFFFF), Color(0xFFE5E5E5), Color(0xFFCFCFCF)]
                                    : [Color.lerp(_white, Colors.white, 0.45)!, _white, Color.lerp(_white, Colors.black, 0.12)!],
                              )
                            : null,
                      ),
                      child: Text(
                        label,
                        style: CrText.label(_type == t ? (t == 'income' ? const Color(0xFF0A0A0A) : _black) : ink)
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String get _display => _type == 'income' && _amount > 0 ? '+ ${_money(_amount)}' : _money(_amount);

  String _money(double v) => formatMoney(v, _selectedAccount?.currency ?? 'COP');

  Widget _amountStep() {
    const ink = Color(0xFFF5F5F5);
    const muted = Color(0xFFD4D4D4);
    final rate = context.app.reminders.hourlyRate;
    return Column(
      key: const ValueKey('amount'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 14),
        Text(_type == 'income' ? '¿cuánto entró?' : '¿cuánto gastaste?', style: CrText.mono(muted, size: 11.5)),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_display, style: CrText.display(_type == 'income' ? const Color(0xFFFFFFFF) : ink, size: 48)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _amount <= 0
              ? 'Escribe el monto'
              : (_type == 'expense' && rate != null && rate > 0 ? 'Unas ${formatHours(_amount / rate)} de tu trabajo' : ' '),
          style: CrText.label(muted),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.1,
          children: [
            for (final k in const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0', '⌫'])
              _Key(label: k, semantic: k == '⌫' ? 'Borrar' : k, onPressed: () => _press(k)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _GhostButton(label: 'Cancelar', onPressed: _dismiss),
            const SizedBox(width: 8),
            Expanded(
              child: _NeonButton(
                label: 'Elegir categoría',
                income: _type == 'income',
                onPressed: _amount > 0 ? () => setState(() => _step = _Step.details) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailsStep() {
    const ink = Color(0xFFF5F5F5);
    const muted = Color(0xFFD4D4D4);
    final cats = _kindCategories;
    final income = _type == 'income';
    return Column(
      key: const ValueKey('details'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Volver al monto',
              onPressed: () => setState(() => _step = _Step.amount),
              style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.08)),
              icon: Transform.rotate(angle: 1.5708, child: const CrIcon('chevron', color: ink, size: 18)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(income ? 'ingreso' : 'gasto', style: CrText.mono(muted, size: 11)),
                  Text(_display, style: CrText.amount(income ? const Color(0xFFFFFFFF) : ink)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CrHeadlineLite(income ? '¿De *dónde*?' : '¿En *qué*?', accent: income ? const Color(0xFFFFFFFF) : const Color(0xFFD9D9D9)),
        const SizedBox(height: 10),
        if (cats.isEmpty)
          Text(
            _categories.isEmpty && _error == null ? 'Cargando categorías…' : 'Sin categorías: se guardará sin categoría.',
            style: CrText.label(muted),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 236),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: [
                for (final (i, c) in cats.indexed)
                  _CategoryChip(
                    name: c.name,
                    color: _palette[i % _palette.length],
                    selected: _category == c.id,
                    accent: income ? const Color(0xFFF5F5F5) : _white,
                    onTap: () => setState(() => _category = _category == c.id ? null : c.id),
                  ),
              ],
            ),
          ),
        if (cats.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('las que más usas a esta hora van primero', style: CrText.mono(muted, size: 10.5)),
        ],
        const SizedBox(height: 12),
        _AccountRow(
          accounts: _accounts,
          value: _account,
          label: income ? 'entra en' : 'cuenta',
          onChanged: (v) => setState(() => _account = v),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error is ApiError ? (_error as ApiError).message : 'No se pudo guardar', style: CrText.label(const Color(0xFFE5E5E5))),
        ],
        const SizedBox(height: 14),
        _NeonButton(
          label: _busy ? 'Guardando…' : (income ? 'Guardar ingreso' : 'Guardar gasto'),
          income: income,
          onPressed: _busy || _account == null ? null : _save,
        ),
      ],
    );
  }

  Widget _doneStep() {
    const muted = Color(0xFFD4D4D4);
    final cat = _categories.where((c) => c.id == _category).firstOrNull?.name;
    final account = _selectedAccount?.name;
    final what =
        '${_money(_amount)}${cat == null ? '' : ' en $cat'}${account == null ? '' : ', ${_type == 'income' ? 'a' : 'de'} $account'}.';
    return Column(
      key: const ValueKey('done'),
      mainAxisSize: MainAxisSize.min,
      children: [
        MoodFace(expression: FinanceMood.faces[4], size: 120, semanticLabel: 'Alvi radiante'),
        const SizedBox(height: 4),
        CrHeadlineLite('Listo, *anotado*.', accent: const Color(0xFFFFFFFF), size: 26),
        const SizedBox(height: 6),
        Text(
          _queued ? '$what\nSin conexión: se enviará al abrir Alvea con internet.' : what,
          textAlign: TextAlign.center,
          style: CrText.body(muted),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _GhostButton(label: 'Deshacer', onPressed: _queued ? null : _undo),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GhostButton(label: 'Otro más', onPressed: _again),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('se cierra solo en 3 s', style: CrText.mono(muted, size: 11)),
      ],
    );
  }
}

/// Grises de las fichas de categoría (la app es monocroma: se distinguen por luz, no por color).
const _palette = [
  Color(0xFFF5F5F5),
  Color(0xFFBDBDBD),
  Color(0xFF8F8F8F),
  Color(0xFFDADADA),
  Color(0xFFA3A3A3),
  Color(0xFF7A7A7A),
  Color(0xFFCFCFCF),
  Color(0xFFB0B0B0),
  Color(0xFFE5E5E5),
];

/// El recuadro rápido siempre es oscuro: la acción va en blanco con texto negro.
const _white = Color(0xFFF5F5F5);
const _black = Color(0xFF0A0A0A);

/// Titular corto con una palabra en serif cursiva (`*así*`).
class CrHeadlineLite extends StatelessWidget {
  const CrHeadlineLite(this.text, {super.key, required this.accent, this.size = 20});
  final String text;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('*');
    return Text.rich(
      TextSpan(
        style: TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: FontWeight.w700, color: const Color(0xFFF5F5F5)),
        children: [
          for (final (i, p) in parts.indexed)
            TextSpan(
              text: p,
              style: i.isOdd
                  ? TextStyle(
                      fontFamily: serifFamily,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                      fontSize: size * 1.2,
                      color: accent,
                    )
                  : null,
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Fondo del recuadro: cristal oscuro con reflejo y borde iluminado hacia el color de la acción.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, required this.accent});
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(30));
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xF21A1A1A), const Color(0xF20E0E0E), Color.lerp(const Color(0xF20E0E0E), accent, 0.10)!],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.2),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 40, spreadRadius: -8)],
        ),
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 16), child: child),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.semantic, required this.onPressed});
  final String label, semantic;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantic,
    excludeSemantics: true,
    child: Material(
      color: Colors.white.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: Center(
          child: label == '⌫'
              ? const CrIcon('backspace', color: Color(0xFFF5F5F5), size: 22)
              : Text(label, style: CrText.display(const Color(0xFFF5F5F5), size: 22)),
        ),
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.name, required this.color, required this.selected, required this.accent, required this.onTap});
  final String name;
  final Color color, accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: name,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.7 : 0.14),
            width: selected ? 1.5 : 1,
          ),
          gradient: LinearGradient(
            colors: selected
                ? [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0.10)]
                : [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.02)],
          ),
          boxShadow: selected ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 18)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [BoxShadow(color: color, blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CrText.label(const Color(0xFFF5F5F5)).copyWith(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.accounts, required this.value, required this.label, required this.onChanged});
  final List<Account> accounts;
  final String? value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFFD4D4D4);
    final a = accounts.where((x) => x.id == value).firstOrNull;
    return Semantics(
      button: true,
      label: 'Cuenta: ${a?.name ?? 'ninguna'}. Cambiar',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: accounts.length < 2
            ? null
            : () async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: const Color(0xFF141414),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (ctx) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        for (final x in accounts)
                          ListTile(
                            title: Text(x.name, style: CrText.body(const Color(0xFFF5F5F5))),
                            subtitle: Text(formatMoney(x.balance, x.currency), style: CrText.label(muted)),
                            trailing: x.id == value ? const CrIcon('check', color: Color(0xFFFFFFFF)) : null,
                            onTap: () => Navigator.of(ctx).pop(x.id),
                          ),
                      ],
                    ),
                  ),
                );
                if (picked != null) onChanged(picked);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFF3A3A3A),
                child: Text(
                  a == null || a.name.isEmpty ? '·' : a.name.substring(0, 1).toUpperCase(),
                  style: CrText.label(Colors.white).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: CrText.mono(muted, size: 10.5)),
                    Text(
                      a == null ? 'Crea una cuenta en la app' : '${a.name} · ${formatMoney(a.balance, a.currency)}',
                      style: CrText.label(const Color(0xFFF5F5F5)).copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (accounts.length > 1) Text('Cambiar', style: CrText.label(const Color(0xFFD9D9D9)).copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeonButton extends StatelessWidget {
  const _NeonButton({required this.label, required this.onPressed, this.income = false});
  final String label;
  final VoidCallback? onPressed;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final base = income ? const Color(0xFFF5F5F5) : _white;
    final on = onPressed != null;
    return Semantics(
      button: true,
      enabled: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: on ? 1 : 0.45,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(base, Colors.white, 0.45)!, base, Color.lerp(base, Colors.black, 0.12)!],
              ),
              boxShadow: on ? [BoxShadow(color: base.withValues(alpha: 0.5), blurRadius: 24)] : null,
            ),
            child: Text(label, style: CrText.body(income ? const Color(0xFF0A0A0A) : _black).copyWith(fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.04)]),
          ),
          child: Text(label, style: CrText.body(const Color(0xFFF5F5F5)).copyWith(fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );
}

/// Para pruebas: el recuadro con un tema oscuro, sin canal nativo.
@visibleForTesting
Widget quickAddForTest(AppState state, {String type = 'expense'}) => QuickAddApp(state: state, type: type);

/// El mismo recuadro rápido, dentro de la app (botón «+» de la barra inferior).
Future<void> showQuickAdd(BuildContext context, {String type = 'expense'}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (ctx, _, _) => Material(
    type: MaterialType.transparency,
    child: QuickAddSheet(type: type, onClose: () => Navigator.of(ctx).pop()),
  ),
  transitionBuilder: (ctx, anim, _, child) {
    final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  },
);
