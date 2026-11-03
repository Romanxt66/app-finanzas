import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Guarda bytes como archivo descargado por el navegador. Devuelve si se guardó (siempre: el navegador
/// lo descarga sin preguntar).
Future<bool> saveFile(List<int> bytes, String filename, {String mime = 'text/csv'}) async {
  final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
