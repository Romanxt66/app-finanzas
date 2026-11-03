import 'dart:io';

/// El dispositivo real es Android (en las pruebas es el sistema del equipo, no el simulado).
bool get isAndroidDevice => Platform.isAndroid;
