import 'package:flutter/foundation.dart';

/// Fuera del navegador no hay un aviso fiable de conexión sin permisos extra: se da por conectada.
class Online extends ValueNotifier<bool> {
  Online() : super(true);
}
