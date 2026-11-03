import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Código QR dibujado en vectorial: módulos oscuros sobre blanco con margen («quiet zone»),
/// como esperan las cámaras de las apps de autenticación (también en tema oscuro).
class QrView extends StatelessWidget {
  const QrView(this.data, {super.key, this.size = 200, this.semanticLabel});
  final String data;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode(payload: QrPayload.fromString(data), errorCorrectLevel: QrErrorCorrectLevel.medium));
    return Semantics(
      image: true,
      label: semanticLabel ?? 'Código QR',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.06),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: CustomPaint(painter: _QrPainter(image)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);
  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final cell = size.shortestSide / n;
    final path = Path();
    for (var r = 0; r < n; r++) {
      for (var col = 0; col < n; col++) {
        // Un pelín más grande que la celda: evita líneas finas entre módulos al escalar
        if (image.isDark(r, col)) path.addRect(Rect.fromLTWH(col * cell, r * cell, cell + 0.4, cell + 0.4));
      }
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF0A0414));
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
