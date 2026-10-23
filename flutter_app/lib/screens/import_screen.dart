import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/csv.dart';
import '../core/format.dart';
import '../core/reference.dart';
import '../core/state.dart';
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

  List<List<String>> get _rows => _text == null ? const [] : parseCsv(_text!, _delimiter);

  Future<void> _pick() async {
    setState(() {
      _result = null;
      _fileError = null;
    });
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv', 'txt']);
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
    final header = looksLikeHeader(parsed.first);
    final body = header ? parsed.skip(1).toList() : parsed;
    final dateGuess = guessMapping(header ? parsed.first : const [], DateFormatKind.dmy);
    final samples = [
      for (final r in body.take(20)) (dateGuess.date >= 0 && dateGuess.date < r.length) ? r[dateGuess.date] : (r.isNotEmpty ? r[0] : ''),
    ];
    final fmt = guessDateFormat(samples);
    setState(() {
      _text = content;
      _fileName = file.name;
      _delimiter = sep;
      _hasHeader = header;
      _mapping = header
          ? guessMapping(parsed.first, fmt)
          : Mapping(date: 0, description: 1, amount: 2, debit: -1, credit: -1, dateFormat: fmt);
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
              for (final it in chunk) {'occurred_on': it.occurredOn, 'description': it.description, 'amount': it.amount},
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
    List<(int, String)> cols(String none) => [(-1, none), for (var i = 0; i < columns; i++) (i, columnLabel(i))];

    return PageScaffold(
      children: [
        PageHead('Importar movimientos'),
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
              Text(
                'El archivo se lee en tu navegador; solo se envían las filas que confirmes. Máximo 2 MB y 1000 filas por envío.',
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
        if (_text != null && _mapping != null)
          CrCard(
            title: '3. Vista previa',
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
