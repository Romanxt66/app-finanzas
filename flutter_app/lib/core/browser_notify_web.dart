import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Permiso de avisos del navegador: 'granted', 'denied', 'default' o 'unsupported'.
String notificationPermission() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestNotificationPermission() async => (await web.Notification.requestPermission().toDart).toDart;

void showNotification(String title, String body, String tag) {
  try {
    web.Notification(title, web.NotificationOptions(body: body, tag: tag, icon: 'icons/Icon-192.png'));
  } catch (_) {}
}
