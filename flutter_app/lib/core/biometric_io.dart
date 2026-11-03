import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

final _auth = LocalAuthentication();

/// El dispositivo puede verificar al usuario (huella, rostro o, si no, su PIN/patrón del teléfono).
Future<bool> biometricAvailable() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _auth.isDeviceSupported();
  } catch (_) {
    return false;
  }
}

/// Muestra el diálogo del sistema. Devuelve si el usuario se verificó (cancelar o fallar = false).
Future<bool> authenticateBiometric(String reason) async {
  try {
    return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
  } catch (_) {
    return false;
  }
}
