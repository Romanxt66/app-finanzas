import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Abre el diálogo del sistema para elegir dónde guardar el archivo. Devuelve si se guardó.
Future<bool> saveFile(List<int> bytes, String filename, {String mime = 'text/csv'}) async {
  final uri = await FilePicker.saveFile(fileName: filename, bytes: Uint8List.fromList(bytes), mimeType: mime);
  return uri != null;
}
