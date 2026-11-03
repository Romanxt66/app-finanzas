/// En el navegador no hay desbloqueo biométrico.
Future<bool> biometricAvailable() async => false;

Future<bool> authenticateBiometric(String reason) async => false;
