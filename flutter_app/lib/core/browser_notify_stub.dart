/// Fuera del navegador (tests, escritorio) no hay avisos del sistema.
String notificationPermission() => 'unsupported';

Future<String> requestNotificationPermission() async => 'unsupported';

void showNotification(String title, String body, String tag) {}
