/// Huella, rostro o bloqueo del teléfono para abrir la app (solo en la app nativa; en la web no hay).
library;

export 'biometric_stub.dart' if (dart.library.io) 'biometric_io.dart';
