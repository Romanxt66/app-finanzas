import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ID de cliente OAuth «Alvea web»: el ID token que pide la app va dirigido a él (lo exige Android para
/// enviarlo a un servidor) y el backend lo acepta porque está en GOOGLE_CLIENT_IDS. Es público.
const googleServerClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue: '2627257012-06rocpn2pjiqqa6flkl0pri5gfcnqrps.apps.googleusercontent.com',
);

/// «Continuar con Google» solo en Android: la web usa su propio botón y en otras plataformas no hay
/// cliente configurado.
bool get googleSignInAvailable => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void>? _init;

/// Abre el selector de cuentas de Google y devuelve el ID token, o null si se canceló.
Future<String?> googleIdToken() async {
  final g = GoogleSignIn.instance;
  await (_init ??= g.initialize(serverClientId: googleServerClientId));
  try {
    final account = await g.authenticate(scopeHint: const ['email', 'profile']);
    return account.authentication.idToken;
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) return null;
    rethrow;
  }
}
