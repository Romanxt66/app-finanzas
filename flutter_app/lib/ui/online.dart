import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Estado de conexión del navegador (como `useOnline`).
class Online extends ValueNotifier<bool> {
  Online() : super(web.window.navigator.onLine) {
    web.window.addEventListener('online', ((web.Event _) => value = true).toJS);
    web.window.addEventListener('offline', ((web.Event _) => value = false).toJS);
  }
}
