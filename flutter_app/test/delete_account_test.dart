import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/delete_account.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<(AppState, List<http.Request>)> open(WidgetTester tester, int status) async {
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final sent = <http.Request>[];
    final client = MockClient((req) async {
      sent.add(req);
      if (req.method == 'DELETE') {
        return status == 204 ? http.Response('', 204) : http.Response(jsonEncode({'detail': 'Not Found'}), status);
      }
      return http.Response('[]', 200);
    });
    final state = AppState(prefs, client: ApiClient(prefs, client: client, baseUrl: 'http://x'));
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const Scaffold(body: SingleChildScrollView(child: DeleteAccountCard())),
        ),
      ),
    );
    await tester.tap(find.text('Eliminar mi cuenta'));
    await tester.pumpAndSettle();
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'secreta-123');
    await tester.enterText(fields.at(1), 'eliminar');
    await tester.pump();
    await tester.tap(find.text('Eliminar para siempre'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    return (state, sent);
  }

  testWidgets('pide la contraseña, borra la cuenta y cierra la sesión', (tester) async {
    final (state, sent) = await open(tester, 204);
    final del = sent.firstWhere((r) => r.method == 'DELETE');
    expect(del.url.path, endsWith('/auth/me'));
    expect(jsonDecode(del.body), {'password': 'secreta-123'});
    expect(state.user, isNull);
    expect(find.text('Eliminar para siempre'), findsNothing);
  });

  testWidgets('si el servidor aún no lo permite, explica cómo pedirlo', (tester) async {
    await open(tester, 404);
    expect(find.textContaining('se gestiona a mano'), findsOneWidget);
  });
}
