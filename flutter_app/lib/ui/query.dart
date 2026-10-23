import 'package:flutter/material.dart';

import '../core/state.dart';

class QueryResult<T> {
  const QueryResult(this.data, this.error, this.loading);
  final T? data;
  final Object? error;
  final bool loading;
  bool get hasData => data != null;
}

/// Carga asíncrona con caché mínima (react-query): conserva el dato anterior mientras recarga
/// y vuelve a pedirlo cuando cambia [deps] o la "revisión" global de datos.
class Query<T> extends StatefulWidget {
  const Query({super.key, required this.load, required this.builder, this.deps, this.enabled = true});
  final Future<T> Function() load;
  final Object? deps;
  final bool enabled;
  final Widget Function(BuildContext context, QueryResult<T> result) builder;

  @override
  State<Query<T>> createState() => _QueryState<T>();
}

class _QueryState<T> extends State<Query<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;
  int _seq = 0;
  int? _revision;
  Object? _deps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rev = context.app.revision;
    if (_revision != rev) {
      _revision = rev;
      _fetch();
    }
  }

  @override
  void didUpdateWidget(Query<T> old) {
    super.didUpdateWidget(old);
    if (widget.deps != _deps || widget.enabled != old.enabled) _fetch();
  }

  Future<void> _fetch() async {
    _deps = widget.deps;
    if (!widget.enabled) {
      setState(() => _loading = false);
      return;
    }
    final seq = ++_seq;
    setState(() => _loading = true);
    try {
      final data = await widget.load();
      if (!mounted || seq != _seq) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, QueryResult(_data, _error, _loading && _data == null));
}
