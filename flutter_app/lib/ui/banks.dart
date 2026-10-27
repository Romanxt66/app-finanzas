import 'package:flutter/material.dart';

import 'theme.dart';

/// Banco o billetera reconocible por el nombre de la cuenta.
///
/// Los logotipos oficiales son marcas registradas y no se incluyen: se muestra una insignia con los
/// colores de la entidad. Si tienes permiso para usar el logo, guárdalo como `assets/banks/<id>.png`
/// y añade el id a [bankLogoAssets]: la app lo usará en lugar de la insignia.
@immutable
class BankBrand {
  const BankBrand(this.id, this.name, this.mark, this.background, this.foreground, {this.aliases = const [], this.type = 'bank'});
  final String id;
  final String name;

  /// Texto corto de la insignia («N», «BBVA»…).
  final String mark;
  final Color background;
  final Color foreground;

  /// Otras formas de escribirlo (sin tildes y en minúsculas).
  final List<String> aliases;

  /// Tipo de cuenta sugerido al elegirlo (`bank`, `card`, `savings`, `cash`).
  final String type;
}

/// Logos que el usuario añadió en `assets/banks/` (vacío por defecto: no se distribuyen marcas ajenas).
const Set<String> bankLogoAssets = {};

const bankBrands = <BankBrand>[
  // Billeteras y bancos digitales
  BankBrand('nequi', 'Nequi', 'N', Color(0xFF200A3C), Color(0xFFE6007E)),
  BankBrand('daviplata', 'Daviplata', 'DP', Color(0xFFE30613), Colors.white),
  BankBrand('nu', 'Nu', 'nu', Color(0xFF820AD1), Colors.white, aliases: ['nubank', 'nu colombia', 'nu bank']),
  BankBrand('lulo', 'Lulo Bank', 'lulo', Color(0xFFE6FF00), Color(0xFF111111), aliases: ['lulo bank', 'lulobank']),
  BankBrand('rappipay', 'RappiPay', 'R', Color(0xFFFF441F), Colors.white, aliases: ['rappi pay', 'rappi']),
  BankBrand('movii', 'Movii', 'M', Color(0xFF5B2D90), Color(0xFFFFC72C)),
  BankBrand('dale', 'dale!', 'd!', Color(0xFF00C1D4), Colors.white),
  BankBrand('uala', 'Ualá', 'U', Color(0xFF3E63FF), Colors.white),
  BankBrand('mercadopago', 'Mercado Pago', 'MP', Color(0xFF00B1EA), Colors.white, aliases: ['mercado pago']),
  BankBrand('paypal', 'PayPal', 'P', Color(0xFF003087), Color(0xFF009CDE)),
  BankBrand('revolut', 'Revolut', 'R', Color(0xFF111111), Colors.white),
  BankBrand('wise', 'Wise', 'W', Color(0xFF9FE870), Color(0xFF163300)),
  // Bancos de Colombia
  BankBrand('bancolombia', 'Bancolombia', 'B', Color(0xFF000000), Color(0xFFFDDA24)),
  BankBrand('davivienda', 'Davivienda', 'D', Color(0xFFE30613), Colors.white),
  BankBrand('bogota', 'Banco de Bogotá', 'BB', Color(0xFF003C71), Colors.white, aliases: ['banco de bogota', 'bogota']),
  BankBrand('bbva', 'BBVA', 'BBVA', Color(0xFF004481), Colors.white),
  BankBrand('colpatria', 'Scotiabank Colpatria', 'S', Color(0xFFEC111A), Colors.white, aliases: ['colpatria', 'scotiabank']),
  BankBrand('popular', 'Banco Popular', 'BP', Color(0xFF00843D), Colors.white, aliases: ['banco popular']),
  BankBrand('avvillas', 'AV Villas', 'AV', Color(0xFF0050A0), Color(0xFFFFD100), aliases: ['av villas']),
  BankBrand('occidente', 'Banco de Occidente', 'BO', Color(0xFF0A3D91), Colors.white, aliases: ['banco de occidente', 'occidente']),
  BankBrand('itau', 'Itaú', 'itaú', Color(0xFFEC7000), Color(0xFF003399)),
  BankBrand('cajasocial', 'Banco Caja Social', 'CS', Color(0xFF003DA5), Colors.white, aliases: ['caja social']),
  BankBrand('falabella', 'Banco Falabella', 'F', Color(0xFF43B02A), Colors.white, aliases: ['falabella']),
  BankBrand('agrario', 'Banco Agrario', 'BA', Color(0xFF00843D), Color(0xFFFFD100), aliases: ['banco agrario']),
  BankBrand('pichincha', 'Banco Pichincha', 'P', Color(0xFFFFDD00), Color(0xFF0F265C), aliases: ['pichincha']),
  BankBrand('gnb', 'GNB Sudameris', 'GNB', Color(0xFF00205B), Colors.white, aliases: ['sudameris']),
  BankBrand('serfinanza', 'Serfinanza', 'SF', Color(0xFF00A651), Colors.white),
  // Otros países
  BankBrand('santander', 'Santander', 'S', Color(0xFFEC0000), Colors.white),
  BankBrand('caixabank', 'CaixaBank', 'CX', Color(0xFF007EAE), Colors.white, aliases: ['caixa', 'la caixa']),
  BankBrand('ing', 'ING', 'ING', Color(0xFFFF6200), Colors.white),
  BankBrand('sabadell', 'Banco Sabadell', 'BS', Color(0xFF006DFF), Colors.white, aliases: ['sabadell']),
  BankBrand('bancoestado', 'BancoEstado', 'BE', Color(0xFFFF7900), Colors.white, aliases: ['banco estado']),
  BankBrand('banamex', 'Banamex', 'B', Color(0xFF002D72), Colors.white, aliases: ['citibanamex']),
  BankBrand('banorte', 'Banorte', 'B', Color(0xFFEB0029), Colors.white),
];

String _plain(String s) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Entidad que aparece en el nombre de la cuenta («Nequi ahorros» → Nequi), o null.
/// Se buscan palabras completas para no confundir, por ejemplo, «ing» dentro de «ingresos».
BankBrand? bankFor(String accountName) {
  final words = ' ${_plain(accountName)} ';
  BankBrand? best;
  var bestLen = 0;
  for (final b in bankBrands) {
    for (final key in [b.id, _plain(b.name), ...b.aliases.map(_plain)]) {
      if (key.length > bestLen && words.contains(' $key ')) {
        best = b;
        bestLen = key.length;
      }
    }
  }
  return best;
}

/// Logo de la cuenta: el de la entidad si se reconoce por el nombre; si no, iniciales.
class BankLogo extends StatelessWidget {
  const BankLogo({super.key, required this.name, required this.fallback, this.color, this.size = 34});
  final String name;

  /// Texto si no se reconoce la entidad (normalmente las iniciales).
  final String fallback;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final brand = bankFor(name);
    if (brand != null && bankLogoAssets.contains(brand.id)) {
      return Semantics(
        label: brand.name,
        image: true,
        child: ClipOval(
          child: Image.asset('assets/banks/${brand.id}.png', width: size, height: size, fit: BoxFit.cover),
        ),
      );
    }
    final bg = brand?.background ?? Color.lerp(color ?? c.neon, c.bg, 0.55)!;
    final fg = brand?.foreground ?? c.ink;
    final text = brand?.mark ?? fallback;
    return Semantics(
      label: brand?.name,
      image: brand != null,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: brand != null ? Colors.white.withValues(alpha: 0.25) : (color ?? c.neon).withValues(alpha: 0.55)),
          boxShadow: brand != null ? [BoxShadow(color: bg.withValues(alpha: 0.45), blurRadius: 10)] : null,
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallback,
                fontSize: size * (text.length <= 2 ? 0.42 : 0.30),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
