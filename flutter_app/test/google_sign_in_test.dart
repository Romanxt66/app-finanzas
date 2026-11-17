import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/auth_screens.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(AppState, List<Map<String, dynamic>>)> _app(WidgetTester tester, {required bool twoFactor, bool signup = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final bodies = <Map<String, dynamic>>[];
  final client = MockClient((req) async {
    if (req.url.path.endsWith('/auth/google')) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      bodies.add(body);
      if (twoFactor && body['otp'] == null) {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {'code': 'otp_required', 'message': 'Escribe el código'},
            }),
          ),
          401,
        );
      }
      return http.Response(jsonEncode({'access_token': 'a', 'refresh_token': 'r', 'token_type': 'bearer'}), 200);
    }
    final body = req.url.path.endsWith('/auth/me')
        ? {'id': 'u1', 'email': 'ana@example.com', 'full_name': 'Ana', 'email_login': false}
        : <dynamic>[];
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });
  final state = AppState(
    prefs,
    client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
  );
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GoogleSignInSection(signup: signup, getToken: () async => 'google-id-token-123456789'),
          ),
        ),
      ),
    ),
  );
  return (state, bodies);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('continuar con Google envía el ID token y deja la sesión iniciada', (tester) async {
    final (state, bodies) = await _app(tester, twoFactor: false);
    await tester.tap(find.text('Continuar con Google'));
    await _settle(tester);
    expect(bodies.single, {'id_token': 'google-id-token-123456789'});
    expect(state.user?.email, 'ana@example.com');
    // Cuenta creada con Google: sin contraseña todavía
    expect(state.user?.emailLogin, isFalse);
  });

  testWidgets('con dos pasos pide el código y reenvía el mismo token', (tester) async {
    final (state, bodies) = await _app(tester, twoFactor: true);
    await tester.tap(find.text('Continuar con Google'));
    await _settle(tester);
    expect(find.text('Código de verificación'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '123 456');
    await tester.tap(find.text('Entrar con Google'));
    await _settle(tester);
    expect(bodies.last, {'id_token': 'google-id-token-123456789', 'otp': '123456'});
    expect(state.user, isNotNull);
  });

  testWidgets('en el registro avisa de que se aceptan los términos y los marca aceptados', (tester) async {
    final (state, _) = await _app(tester, twoFactor: false, signup: true);
    expect(find.textContaining('Al continuar con Google confirmas'), findsOneWidget);
    await tester.tap(find.text('Continuar con Google'));
    await _settle(tester);
    expect(state.legalAccepted, isNotNull);
  });
}
