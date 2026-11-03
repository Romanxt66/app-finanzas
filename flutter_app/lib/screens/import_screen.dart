import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/csv.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/banks.dart';
import '../ui/buttons.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _maxFileBytes = 2 * 1024 * 1024;
const _previewRows = 8;

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String _accountId = '';
  String? _text;
  String _fileName = '';
  String? _fileError;
  String _delimiter = ',';
  bool _hasHeader = true;
  Mapping? _mapping;
  ({int created, int skipped})? _result;
  bool _busy = false;
  Object? _error;
  bool _accountMissing = false;

  /// Filas iniciales que no son la tabla (datos de la cuenta en algunos extractos).
  int _skip = 0;

  /// Entidad reconocida en el archivo (nombre o contenido), para elegir la cuenta sola.
  BankBrand? _bank;

  /// Categoría elegida por grupo de movimientos iguales (ver [categoryGroupKey]); null = sin categoría.
  final Map<String, String?> _cats = {};

  /// Grupos cuya categoría propuso la app (y no el usuario).
  final Set<String> _suggested = {};
  String _suggestedFor = '';
  bool _suggesting = false;
  bool _showAllGroups = false;

  List<List<String>> get _rows {
    if (_text == null) return const [];
    final all = parseCsv(_text!, _delimiter);
    return _skip > 0 && _skip < all.length ? all.sublist(_skip) : all;
  }

  Future<void> _pick() async {
    setState(() {
      _result = null;
      _fileError = null;
    });
    final lock = context.app.lock;
    final file = await lock.whileAway(() => FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv', 'txt']));
    if (file == null) return;
    if ((await file.length() ?? 0) > _maxFileBytes) {
      setState(() => _fileError = 'El archivo supera los 2 MB');
      return;
    }
    final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    final sep = detectDelimiter(content);
    final parsed = parseCsv(content, sep);
    if (parsed.length < 2) {
      setState(() => _fileError = 'El archivo no tiene filas de datos');
      return;
    }
    final headerRow = findHeaderRow(parsed);
    final skip = headerRow > 0 ? headerRow : 0;
    final table = parsed.sublist(skip);
    final header = headerRow >= 0 || looksLikeHeader(table.first);
    final body = header ? table.skip(1).toList() : table;
    final dateGuess = guessMapping(header ? table.first : const [], DateFormatKind.dmy);
    final samples = [
      for (final r in body.take(20)) (dateGuess.date >= 0 && dateGuess.date < r.length) ? r[dateGuess.date] : (r.isNotEmpty ? r[0] : ''),
    ];
    final fmt = guessDateFormat(samples);
    if (!mounted) return;
    final bank = bankFor(file.name) ?? bankFor(parsed.take(skip + 1).expand((r) => r).join(' '));
    final accounts = context.ref.accounts;
    setState(() {
      _text = content;
      _fileName = file.name;
      _delimiter = sep;
      _skip = skip;
      _hasHeader = header;
      _bank = bank;
      _cats.clear();
      _suggested.clear();
      _suggestedFor = '';
      _mapping = header
          ? guessMapping(table.first, fmt)
          : Mapping(date: 0, description: 1, amount: 2, debit: -1, credit: -1, dateFormat: fmt);
      if (_accountId.isEmpty && bank != null) {
        final match = accounts.where((a) => bankFor(a.name)?.id == bank.id).toList();
        if (match.length == 1) _accountId = match.single.id;
      }
    });
  }

  /// Pide al servidor una categoría para cada grupo nuevo (una vez por combinación de filas).
  void _ensureSuggestions(List<ImportItem> items) {
    final groups = <String, ImportItem>{for (final it in items) categoryGroupKey(it): it};
    final signature = groups.keys.join('\n');
    if (signature == _suggestedFor || groups.isEmpty || _suggesting) return;
    _suggestedFor = signature;
    final pending = groups.entries.where((e) => !_cats.containsKey(e.key)).take(1000).toList();
    if (pending.isEmpty) return;
    final app = context.app;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _suggesting = true);
      try {
        final res = await app.api.post(
          '/transactions/categorize',
          body: {
            'items': [
              for (final e in pending) {'description': e.value.description, 'amount': e.value.amount},
            ],
          },
        ) as Map<String, dynamic>;
        final list = res['suggestions'] as List<dynamic>;
        if (!mounted) return;
        setState(() {
          for (var i = 0; i < pending.length && i < list.length; i++) {
            final id = (list[i] as Map<String, dynamic>)['category_id'] as String?;
            _cats.putIfAbsent(pending[i].key, () => id);
            if (id != null) _suggested.add(pending[i].key);
          }
        });
      } catch (_) {
        // Las sugerencias son una ayuda: si fallan, se importa sin categoría (o con la que elija el usuario).
        // No se reintenta hasta que cambien las filas, para no repetir la petición en cada repintado.
      } finally {
        if (mounted) setState(() => _suggesting = false);
      }
    });
  }

  Future<void> _run(List<ImportItem> items) async {
    if (_accountId.isEmpty) {
      setState(() => _accountMissing = true);
      return;
    }
    final app = context.app;
    setState(() {
      _busy = true;
      _error = null;
    });
    var created = 0, skipped = 0;
    try {
      for (var i = 0; i < items.length; i += 500) {
        final chunk = items.skip(i).take(500).toList();
        final res = await app.api.post(
          '/transactions/bulk',
          body: {
            'account_id': _accountId,
            'items': [
              for (final it in chunk)
                {
                  'occurred_on': it.occurredOn,
                  'description': it.description,
                  'amount': it.amount,
                  'category_id': ?_cats[categoryGroupKey(it)],
                },
            ],
            'skip_duplicates': true,
          },
        ) as Map<String, dynamic>;
        created += res['created'] as int;
        skipped += res['skipped'] as int;
      }
      if (created > 0) app.onToast?.call('Se importaron $created movimientos');
      setState(() {
        _result = (created: created, skipped: skipped);
        _text = null;
        _cats.clear();
        _suggested.clear();
        _suggestedFor = '';
      });
      app.invalidate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          if (created > 0) _result = (created: created, skipped: skipped);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final c = context.c;
    final rows = _rows;
    final header = _hasHeader && rows.isNotEmpty ? rows.first : null;
    final data = _hasHeader && rows.isNotEmpty ? rows.skip(1).toList() : rows;
    final columns = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    String columnLabel(int i) =>
        (header != null && i < header.length && header[i].trim().isNotEmpty) ? header[i].trim() : 'Columna ${i + 1}';
    final parsed = _mapping == null
        ? (items: <ImportItem>[], errors: <({int row, String reason})>[])
        : buildItems(data, _mapping!, _hasHeader ? 2 : 1);
    final account = ref.accounts.where((a) => a.id == _accountId).firstOrNull;
    final ready = account != null && _mapping != null && parsed.items.isNotEmpty && _mapping!.date >= 0;
    if (_mapping != null && parsed.items.isNotEmpty) _ensureSuggestions(parsed.items);
    final groups = <String, ({ImportItem sample, int count})>{};
    for (final it in parsed.items) {
      final key = categoryGroupKey(it);
      groups[key] = (sample: groups[key]?.sample ?? it, count: (groups[key]?.count ?? 0) + 1);
    }
    final categorized = parsed.items.where((it) => _cats[categoryGroupKey(it)] != null).length;
    final groupList = groups.entries.toList()..sort((a, b) => b.value.count.compareTo(a.value.count));
    List<(int, String)> cols(String none) => [(-1, none), for (var i = 0; i < columns; i++) (i, columnLabel(i))];

    return PageScaffold(
      children: [
        PageHead('Importar movimientos', headline: 'Trae tu banco *en segundos*.'),
        CrCard(
          title: '1. Cuenta y archivo',
          child: Stack12(
            children: [
              CrSelect<String>(
                label: 'Cuenta de destino',
                value: _accountId,
                error: _accountMissing && _accountId.isEmpty ? 'Elige la cuenta de destino.' : null,
                options: [('', 'Selecciona…'), for (final a in ref.accounts) (a.id, '${a.name} (${a.currency})')],
                onChanged: (v) => setState(() {
                  _accountId = v;
                  _accountMissing = false;
                }),
              ),
              CrField(
                label: 'Archivo CSV del banco',
                error: _fileError,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CrButton(icon: 'download', label: _text != null ? _fileName : 'Elegir archivo…', onPressed: _pick),
                ),
              ),
              if (_text != null && (_bank != null || _skip > 0))
                Row(
                  children: [
                    if (_bank != null) ...[BankLogo(name: _bank!.name, fallback: '', size: 22), const SizedBox(width: space2)],
                    Expanded(
                      child: Text(
                        [
                          if (_bank != null) 'Extracto de ${_bank!.name}',
                          if (_skip > 0) 'se saltaron $_skip filas de información antes de la tabla',
                        ].join(' · '),
                        style: CrText.caption(c.inkMuted),
                      ),
                    ),
                  ],
                ),
              Text(
                'El archivo se lee en tu ${kIsWeb ? 'navegador' : 'teléfono'}; solo se envían las filas que confirmes. '
                'Máximo 2 MB y 1000 filas por envío.',
                style: CrText.caption(c.inkMuted),
              ),
            ],
          ),
        ),
        if (_result != null)
          CrCard(
            child: Semantics(
              liveRegion: true,
              child: Text.rich(
                TextSpan(
                  style: CrText.body(c.ink),
                  children: [
                    const TextSpan(text: 'Se importaron '),
                    TextSpan(
                      text: '${_result!.created}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: ' movimientos${_result!.skipped > 0 ? ' (${_result!.skipped} ya existían y se omitieron)' : ''}.'),
                  ],
                ),
              ),
            ),
          ),
        if (_text != null && _mapping != null)
          CrCard(
            title: '2. Columnas · $_fileName',
            child: Stack12(
              children: [
                FormGrid(
                  children: [
                    CrSelect<String>(
                      label: 'Separador',
                      value: _delimiter,
                      options: const [(',', 'Coma (,)'), (';', 'Punto y coma (;)'), ('\t', 'Tabulador')],
                      onChanged: (v) => setState(() => _delimiter = v),
                    ),
                    CrSelect<DateFormatKind>(
                      label: 'Formato de fecha',
                      value: _mapping!.dateFormat,
                      options: const [
                        (DateFormatKind.dmy, 'Día/Mes/Año'),
                        (DateFormatKind.mdy, 'Mes/Día/Año'),
                        (DateFormatKind.ymd, 'Año-Mes-Día'),
                      ],
                      onChanged: (v) => setState(() => _mapping!.dateFormat = v),
                    ),
                    CrSelect<int>(
                      label: 'Columna de fecha',
                      value: _mapping!.date,
                      options: cols('—'),
                      onChanged: (v) => setState(() => _mapping!.date = v),
                    ),
                    CrSelect<int>(
                      label: 'Columna de descripción',
                      value: _mapping!.description,
                      options: cols('(sin descripción)'),
                      onChanged: (v) => setState(() => _mapping!.description = v),
                    ),
                    CrSelect<int>(
                      label: 'Columna de monto (con signo)',
                      value: _mapping!.amount,
                      options: cols('Usar débito y crédito'),
                      onChanged: (v) => setState(() => _mapping!.amount = v),
                    ),
                    if (_mapping!.amount < 0) ...[
                      CrSelect<int>(
                        label: 'Columna de débito (gasto)',
                        value: _mapping!.debit,
                        options: cols('—'),
                        onChanged: (v) => setState(() => _mapping!.debit = v),
                      ),
                      CrSelect<int>(
                        label: 'Columna de crédito (ingreso)',
                        value: _mapping!.credit,
                        options: cols('—'),
                        onChanged: (v) => setState(() => _mapping!.credit = v),
                      ),
                    ],
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CrCheckbox(
                    value: _hasHeader,
                    onChanged: (v) => setState(() => _hasHeader = v),
                    label: 'La primera fila es el encabezado',
                  ),
                ),
              ],
            ),
          ),
        if (_text != null && _mapping != null && groupList.isNotEmpty)
          CrCard(
            title: '3. Categorías',
            meta: _suggesting ? 'buscando…' : '$categorized de ${parsed.items.length} con categoría',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Alvea propone una categoría según cómo clasificaste antes movimientos parecidos y el nombre del comercio. '
                  'Revísalas: se aplican a todos los movimientos con la misma descripción.',
                  style: CrText.caption(c.inkMuted),
                ),
                const SizedBox(height: space3),
                for (final g in groupList.take(_showAllGroups ? groupList.length : 12))
                  Padding(
                    padding: const EdgeInsets.only(bottom: space2),
                    child: _CategoryGroupRow(
                      description: g.value.sample.description,
                      count: g.value.count,
                      income: !g.value.sample.amount.startsWith('-'),
                      suggested: _suggested.contains(g.key),
                      value: _cats[g.key],
                      categories: [
                        for (final cat in ref.categories)
                          if (cat.kind == (g.value.sample.amount.startsWith('-') ? 'expense' : 'income')) cat,
                      ],
                      onChanged: (id) => setState(() {
                        _cats[g.key] = id;
                        _suggested.remove(g.key);
                      }),
                    ),
                  ),
                if (groupList.length > 12)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CrButton(
                      variant: CrButtonVariant.ghost,
                      small: true,
                      label: _showAllGroups ? 'Ver menos' : 'Ver los ${groupList.length} grupos',
                      onPressed: () => setState(() => _showAllGroups = !_showAllGroups),
                    ),
                  ),
              ],
            ),
          ),
        if (_text != null && _mapping != null)
          CrCard(
            title: '4. Vista previa',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (parsed.items.isEmpty)
                  const CrEmpty('No hay filas válidas con esta configuración.')
                else
                  GlassList(
                    label: 'Vista previa',
                    children: [
                      for (var i = 0; i < parsed.items.take(_previewRows).length; i++)
                        RowSplit(
                          first: i == 0,
                          index: i,
                          children: [
                            Text(
                              parsed.items[i].description.isEmpty ? '(sin descripción)' : parsed.items[i].description,
                              style: CrText.body(c.ink),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(parsed.items[i].occurredOn, style: CrText.caption(c.inkMuted)),
                                const SizedBox(width: space3),
                                Text(
                                  formatMoney(
                                    double.parse(parsed.items[i].amount),
                                    account?.currency,
                                    double.parse(parsed.items[i].amount) > 0,
                                  ),
                                  style: CrText.amountSm(double.parse(parsed.items[i].amount) > 0 ? c.positive : c.ink),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                const SizedBox(height: space3),
                Wrap(
                  spacing: space3,
                  runSpacing: space2,
                  children: [
                    CrBadge('${parsed.items.length} filas válidas', tone: Tone.positive),
                    if (parsed.errors.isNotEmpty) CrBadge('${parsed.errors.length} con errores (se omiten)', tone: Tone.negative),
                  ],
                ),
                if (parsed.errors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: space2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in parsed.errors.take(5)) Text('Fila ${e.row}: ${e.reason}', style: CrText.caption(c.inkMuted)),
                        if (parsed.errors.length > 5) Text('…y ${parsed.errors.length - 5} más', style: CrText.caption(c.inkMuted)),
                      ],
                    ),
                  ),
                const SizedBox(height: space4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CrButton(
                    variant: CrButtonVariant.primary,
                    label: 'Importar ${parsed.items.length} movimientos',
                    onPressed: (!ready && account != null) || _busy ? null : () => _run(parsed.items),
                  ),
                ),
                if (account == null && _accountMissing)
                  Padding(
                    padding: const EdgeInsets.only(top: space1),
                    child: Text('Elige la cuenta de destino.', style: CrText.label(c.negative)),
                  ),
                ErrorText(_error),
              ],
            ),
          ),
      ],
    );
  }
}

/// Un grupo de movimientos con la misma descripción y su categoría (editable).
class _CategoryGroupRow extends StatelessWidget {
  const _CategoryGroupRow({
    required this.description,
    required this.count,
    required this.income,
    required this.suggested,
    required this.value,
    required this.categories,
    required this.onChanged,
  });
  final String description;
  final int count;
  final bool income, suggested;
  final String? value;
  final List<Category> categories;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final label = description.isEmpty ? '(sin descripción)' : description;
    final select = CrSelect<String>(
      label: 'Categoría de «$label»',
      value: value ?? '',
      options: [('', 'Sin categoría'), for (final cat in categories) (cat.id, cat.name)],
      onChanged: (v) => onChanged(v.isEmpty ? null : v),
    );
    final info = Row(
      children: [
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: CrText.body(c.ink)),
        ),
        const SizedBox(width: space2),
        CrBadge('×$count', tone: income ? Tone.positive : Tone.neutral),
        if (suggested) ...[const SizedBox(width: space1), const CrBadge('sugerida', tone: Tone.brand)],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < 560
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: space1),
                select,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: info),
                const SizedBox(width: space3),
                Expanded(flex: 4, child: select),
              ],
            ),
    );
  }
}
