import 'package:flutter/services.dart';

import 'is_android_stub.dart' if (dart.library.io) 'is_android_io.dart';

/// Puente con la parte nativa de Android (MainActivity / QuickAddActivity): widgets del escritorio y
/// pantallas que piden abrir. En la web y en las pruebas no hace nada.
class NativeApp {
  static const channel = MethodChannel('click.softlane.alvea/app');

  static bool get supported => isAndroidDevice;

  /// Ruta con la que un widget abrió la app (si la abrió uno).
  static Future<String?> initialRoute() async {
    if (!supported) return null;
    try {
      return await channel.invokeMethod<String>('initialRoute');
    } catch (_) {
      return null;
    }
  }

  /// Rutas pedidas por un widget con la app ya abierta.
  static void onOpen(void Function(String route) open) {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) open(call.arguments as String);
      return null;
    });
  }

  /// Cuántos widgets de Alvea hay en el escritorio (0 si ninguno: no hace falta dibujarlos).
  static Future<int> widgetCount() async {
    if (!supported) return 0;
    try {
      return await channel.invokeMethod<int>('widgetCount') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Pide a Android que vuelva a pintar los widgets con las imágenes ya guardadas.
  static Future<void> updateWidgets() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('updateWidgets');
    } catch (_) {}
  }

  /// Al cerrar sesión: los widgets dejan de mostrar datos de la cuenta.
  static Future<void> clearWidgets() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('clearWidgets');
    } catch (_) {}
  }
}
