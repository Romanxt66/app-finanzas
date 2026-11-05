import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/glass.dart';
import '../ui/inputs.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

// Términos y condiciones y política de privacidad. Son públicas (se abren sin iniciar sesión) porque Google
// Play pide un enlace a la política y el registro enlaza a ambas. Si cambian, sube [legalVersion]: la app
// vuelve a pedir la aceptación a quien aceptó una versión anterior.

/// Fecha de la versión vigente de los textos legales.
const legalVersion = '2026-11-05';

/// Correo de soporte y de solicitudes sobre datos personales (se define al compilar con
/// `--dart-define=SUPPORT_EMAIL=...`). Si no se define, los textos remiten a la ficha de la tienda.
const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

String get _contact => supportEmail.isNotEmpty
    ? 'escríbenos a $supportEmail'
    : 'escríbenos al correo de contacto que aparece en la ficha de Alvea en Google Play';

enum LegalDoc {
  terms('Términos y condiciones', 'Las reglas, *claras*.', '/terminos'),
  privacy('Política de privacidad', 'Tus datos, *tuyos*.', '/privacidad');

  const LegalDoc(this.title, this.headline, this.path);
  final String title, headline, path;
}

typedef _Section = (String title, List<String> paragraphs);

List<_Section> _terms() => [
  (
    'Qué es Alvea',
    [
      'Alvea es una aplicación para llevar tus finanzas personales: registrar cuentas, movimientos, presupuestos, metas, '
          'suscripciones y recordatorios de cobro. Es una herramienta de organización: no es un banco, no mueve tu dinero '
          'ni se conecta a tus cuentas bancarias.',
      'Al crear una cuenta o usar la app aceptas estos términos. Si no estás de acuerdo, no uses Alvea.',
    ],
  ),
  (
    'Tu cuenta',
    [
      'Debes ser mayor de edad (18 años) para crear una cuenta. Eres responsable de la información que registras y de '
          'mantener segura tu contraseña, tu PIN y el acceso a tu teléfono.',
      'Puedes activar la verificación en dos pasos y el bloqueo con PIN o huella. Si crees que alguien entró a tu cuenta, '
          'cambia la contraseña y cierra las demás sesiones desde Perfil.',
    ],
  ),
  (
    'Sin asesoría financiera',
    [
      'Los resúmenes, avisos, sugerencias y los comentarios de Alvi son orientativos y se calculan a partir de los datos '
          'que tú ingresas. No constituyen asesoría financiera, tributaria ni legal. Las decisiones sobre tu dinero son tuyas.',
    ],
  ),
  (
    'Uso aceptable',
    [
      'No uses Alvea para actividades ilícitas, para intentar acceder a cuentas ajenas, para sobrecargar o vulnerar el '
          'servicio ni para copiarlo o revenderlo. Podemos suspender cuentas que incumplan estas reglas.',
    ],
  ),
  (
    'Disponibilidad',
    [
      'Trabajamos para que Alvea esté disponible y tus datos respaldados, pero el servicio se ofrece «tal cual», sin '
          'garantía de funcionamiento ininterrumpido. Te recomendamos exportar tus movimientos (CSV) de vez en cuando.',
      'En la máxima medida permitida por la ley, no respondemos por pérdidas derivadas de decisiones tomadas con base en '
          'la información de la app ni por interrupciones del servicio.',
    ],
  ),
  (
    'Cerrar tu cuenta',
    [
      'Puedes dejar de usar Alvea cuando quieras y pedir que eliminemos tu cuenta y todos tus datos (ver la política de '
          'privacidad). También podemos cerrar cuentas inactivas o que incumplan estos términos, avisándote antes cuando sea posible.',
    ],
  ),
  (
    'Cambios',
    [
      'Si cambiamos estos términos de forma importante, te lo pediremos aceptar de nuevo dentro de la app. '
          'La fecha de la versión vigente aparece al final.',
      'Estos términos se rigen por las leyes de la República de Colombia. Para dudas, $_contact.',
    ],
  ),
];

List<_Section> _privacy() => [
  (
    'Qué datos guardamos',
    [
      'Datos de la cuenta: nombre, correo y contraseña (guardada cifrada con un algoritmo de un solo sentido; nadie puede leerla).',
      'Datos financieros que tú registras: cuentas, saldos, movimientos, categorías, presupuestos, metas, suscripciones y '
          'archivos que decidas importar (CSV o extractos). No pedimos claves bancarias ni accedemos a tus bancos.',
      'Datos técnicos mínimos: registros de errores de la app (sin el contenido de tus movimientos) para poder corregir fallos, '
          'y las sesiones abiertas (dispositivo y fecha) para que puedas cerrarlas.',
    ],
  ),
  (
    'Para qué los usamos',
    [
      'Solo para darte el servicio: mostrar tus resúmenes, calcular presupuestos y avisos, programar recordatorios en tu '
          'teléfono, proteger tu cuenta y responder tus solicitudes.',
      'No vendemos tus datos, no los usamos para publicidad y no los compartimos con terceros, salvo los proveedores que '
          'alojan el servidor (con obligación de confidencialidad) o cuando una autoridad competente lo exija por ley.',
    ],
  ),
  (
    'Qué queda en tu teléfono',
    [
      'Preferencias (tema, tono, recordatorios), tu sesión, el PIN (cifrado) y una copia temporal de tus datos para que la '
          'app abra rápido y funcione sin conexión. La huella o el rostro nunca salen del teléfono: Alvea solo recibe un sí o un no del sistema.',
      'Los widgets y las notificaciones muestran cifras en tu pantalla de inicio: puedes desactivarlos cuando quieras.',
    ],
  ),
  (
    'Seguridad',
    [
      'Las comunicaciones viajan cifradas (HTTPS), el servidor guarda copias de respaldo y el acceso está protegido con '
          'contraseña y, si la activas, verificación en dos pasos. Ningún sistema es infalible: si detectamos un incidente que '
          'afecte tus datos, te avisaremos.',
    ],
  ),
  (
    'Tus derechos',
    [
      'De acuerdo con la Ley 1581 de 2012 de Colombia (habeas data) y normas afines, puedes conocer, actualizar, rectificar '
          'y exportar tus datos (Movimientos → Exportar CSV), revocar esta autorización y pedir que eliminemos tu cuenta y '
          'todos tus datos. Para ejercerlos, $_contact. Respondemos en un máximo de 15 días hábiles.',
      'Cuando eliminamos una cuenta, borramos sus datos del servidor; las copias de respaldo se sobrescriben en un máximo de 30 días.',
    ],
  ),
  ('Menores de edad', ['Alvea no está dirigida a menores de 18 años y no recopilamos a sabiendas datos de menores.']),
  (
    'Cambios',
    [
      'Si cambiamos esta política de forma importante, te lo pediremos aceptar de nuevo dentro de la app. '
          'La fecha de la versión vigente aparece al final.',
    ],
  ),
];

class LegalScreen extends StatelessWidget {
  const LegalScreen(this.doc, {super.key});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sections = doc == LegalDoc.terms ? _terms() : _privacy();
    final other = doc == LegalDoc.terms ? LegalDoc.privacy : LegalDoc.terms;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: space5, vertical: space5),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CrButton(
                    variant: CrButtonVariant.ghost,
                    small: true,
                    label: 'Volver',
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  ),
                  const SizedBox(height: space4),
                  Rise(child: CrTag(doc.title.toLowerCase())),
                  const SizedBox(height: space3),
                  Rise(
                    delay: const Duration(milliseconds: 60),
                    child: Semantics(header: true, child: CrHeadline(doc.headline, size: 36)),
                  ),
                  const SizedBox(height: space3),
                  Text(
                    doc == LegalDoc.terms
                        ? 'Lo esencial: Alvea te ayuda a ordenar tu dinero, no lo mueve ni te asesora, y puedes irte cuando quieras.'
                        : 'Lo esencial: guardamos lo que tú registras solo para mostrártelo, no lo vendemos y puedes borrarlo todo.',
                    style: CrText.body(c.inkMuted),
                  ),
                  const SizedBox(height: space5),
                  for (final (i, (title, paragraphs)) in sections.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: space3),
                      child: FadeIn(
                        delay: Duration(milliseconds: 40 * (i < 8 ? i : 8)),
                        child: Glass(
                          padding: const EdgeInsets.all(space5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(header: true, child: Text(title, style: CrText.heading(c.ink))),
                              for (final p in paragraphs) ...[
                                const SizedBox(height: space2),
                                Text(p, style: CrText.body(c.inkMuted).copyWith(height: 1.55)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: space2),
                  Text('versión vigente: $legalVersion', style: CrText.mono(c.inkFaint, size: 11.5)),
                  const SizedBox(height: space3),
                  CrButton(
                    variant: CrButtonVariant.glass,
                    small: true,
                    label: 'Leer ${other.title.toLowerCase()}',
                    onPressed: () => context.pushReplacement(other.path),
                  ),
                  const SizedBox(height: space6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ruta que no existe: en vez del error técnico, una salida amable.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(space5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Glass(
                strong: true,
                padding: const EdgeInsets.all(space6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CrEmpty('Esta página no existe o cambió de lugar.'),
                    const SizedBox(height: space4),
                    CrButton(variant: CrButtonVariant.primary, label: 'Ir al inicio', onPressed: () => context.go('/')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto pequeño con enlaces a los documentos legales (registro, acceso y perfil).
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.prefix = ''});
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = CrText.caption(c.inkMuted);
    Widget link(LegalDoc d, String text) => Semantics(
      link: true,
      label: d.title,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(d.path),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              text,
              style: style.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: c.inkFaint,
              ),
            ),
          ),
        ),
      ),
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prefix.isNotEmpty) Text(prefix, style: style),
        link(LegalDoc.terms, 'Términos'),
        Text(' y ', style: style),
        link(LegalDoc.privacy, 'Política de privacidad'),
      ],
    );
  }
}

/// Pide aceptar la versión vigente de los términos a quien entró sin haberla aceptado en este dispositivo
/// (cuentas creadas antes de que existieran, o textos actualizados). No se puede cerrar sin aceptar, pero
/// sí leer los documentos o salir de la cuenta.
class LegalConsent extends StatefulWidget {
  const LegalConsent({super.key});

  @override
  State<LegalConsent> createState() => _LegalConsentState();
}

class _LegalConsentState extends State<LegalConsent> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    final updated = app.legalAccepted != null;
    return Positioned.fill(
      child: FadeIn(
        child: Stack(
          children: [
            ModalBarrier(dismissible: false, color: Colors.black.withValues(alpha: c.isDark ? 0.62 : 0.38)),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(space4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Semantics(
                      scopesRoute: true,
                      explicitChildNodes: true,
                      namesRoute: true,
                      label: 'Términos y privacidad',
                      child: Glass(
                        strong: true,
                        padding: const EdgeInsets.all(space5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CrHeadline(updated ? 'Actualizamos las *reglas*.' : 'Antes de *seguir*.', size: 26),
                            const SizedBox(height: space2),
                            Text(
                              updated ? 'Cambiamos los términos o la política de privacidad. Léelos y acéptalos para seguir usando Alvea.' : 'Para usar Alvea necesitamos que aceptes los términos y la política de privacidad. Son cortos y en lenguaje claro.',
                              style: CrText.body(c.inkMuted),
                            ),
                            const SizedBox(height: space3),
                            CrCheckbox(value: _checked, onChanged: (v) => setState(() => _checked = v), label: 'Leí y acepto'),
                            const LegalLinks(prefix: 'Ver '),
                            const SizedBox(height: space4),
                            Row(
                              children: [
                                CrButton(variant: CrButtonVariant.ghost, small: true, label: 'Salir', onPressed: app.logout),
                                const Spacer(),
                                CrButton(
                                  variant: CrButtonVariant.primary,
                                  label: 'Aceptar y seguir',
                                  onPressed: _checked ? () => app.acceptLegal(legalVersion) : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
