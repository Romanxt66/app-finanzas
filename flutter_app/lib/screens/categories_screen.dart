import 'package:flutter/material.dart';

import '../core/state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _kinds = {'expense': 'Gastos', 'income': 'Ingresos'};

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      await context.app.loadReference();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _edit({
    String? id,
    String? name,
    String kind = 'expense',
  }) async {
    final result = await showSheet(
      context,
      (_) => _CategoryForm(id: id, name: name, kind: kind),
    );
    if (result) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ErrorState(_error!, onRetry: _reload)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                children: [
                  for (final kind in _kinds.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        kind.value,
                        style: TextStyle(
                          color: c.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!app.categories.any((x) => x.kind == kind.key))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Sin categorías de ${kind.value.toLowerCase()}.',
                          style: TextStyle(color: c.inkFaint),
                        ),
                      ),
                    for (final cat in app.categories.where(
                      (x) => x.kind == kind.key,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Glass(
                          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(cat.name)),
                              IconButton(
                                tooltip: 'Renombrar ${cat.name}',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _edit(
                                  id: cat.id,
                                  name: cat.name,
                                  kind: cat.kind,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar ${cat.name}',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  if (await confirm(
                                    context,
                                    'Eliminar categoría',
                                    'Los movimientos de "${cat.name}" quedarán sin categoría.',
                                  )) {
                                    await _run(
                                      () => app.api.delete(
                                        '/categories/${cat.id}',
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.id, this.name, required this.kind});
  final String? id;
  final String? name;
  final String kind;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late String _kind = widget.kind;
  Map<String, List<String>> _suggestions = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final j = await context.app.api.get(
        '/categories/suggestions',
      ) as Map<String, dynamic>;
      if (mounted) {
        setState(
          () => _suggestions = {
            for (final e in j.entries)
              e.key: [for (final s in e.value as List) '$s'],
          },
        );
      }
    } catch (_) {
      // Las sugerencias son opcionales: sin ellas se escribe el nombre a mano.
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    final api = context.app.api;
    try {
      if (widget.id == null) {
        await api.post(
          '/categories',
          body: {'name': _name.text.trim(), 'kind': _kind},
        );
      } else {
        await api.patch(
          '/categories/${widget.id}',
          body: {'name': _name.text.trim()},
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.id == null ? 'Nueva categoría' : 'Renombrar categoría',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (widget.id == null) ...[
          SegmentedButton<String>(
            segments: [
              for (final e in _kinds.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
        ),
        if (widget.id == null && _suggestions[_kind]?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            'Sugerencias',
            style: TextStyle(fontSize: 12, color: context.c.inkMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final s in _suggestions[_kind]!)
                ActionChip(
                  label: Text(s),
                  onPressed: () => setState(() => _name.text = s),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        BusyButton(label: 'Guardar', onPressed: _save),
      ],
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}
