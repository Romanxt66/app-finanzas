import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Guarda la imagen de un widget donde la lee la parte nativa (`files/widgets/<name>.png`).
Future<void> writeWidgetImage(String name, Uint8List png) async {
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/widgets');
  await dir.create(recursive: true);
  // Primero a un temporal y luego se renombra: el widget nunca lee una imagen a medias
  final tmp = File('${dir.path}/$name.tmp');
  await tmp.writeAsBytes(png, flush: true);
  await tmp.rename('${dir.path}/$name.png');
}
