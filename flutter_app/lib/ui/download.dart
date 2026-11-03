/// Guardar un archivo generado por la app (CSV, códigos de recuperación…): descarga del navegador
/// en la web y diálogo «Guardar como» del sistema en Android.
library;

export 'download_io.dart' if (dart.library.js_interop) 'download_web.dart';
