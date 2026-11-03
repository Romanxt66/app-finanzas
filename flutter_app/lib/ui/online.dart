/// Estado de conexión. En el navegador sigue a `navigator.onLine`; en la app nativa se da por
/// conectada (si falla la red, cada pantalla lo muestra con su propio error).
library;

export 'online_stub.dart' if (dart.library.js_interop) 'online_web.dart';
