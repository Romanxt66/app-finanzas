import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/offline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor de mentira que se puede «desconectar».
class FakeServer {
  bool online = true;
  final requests = <http.Request>[];
  final txs = <Map<String, dynamic>>[
    {'id': 't1', 'type': 'expense', 'account_id': 'a1', 'amount': '10', 'description': 'Pan', 'occurred_on': '2026-11-01'},
  ];
  var nextId = 100;

  late final client = MockClient((req) async {
    if (!online) throw Exception('sin red');
    requests.add(req);
    final path = req.url.path.replaceFirst('/api/v1', '');
    if (req.method == 'GET' && path == '/transactions') {
      return http.Response(jsonEncode({'items': txs, 'total': txs.length}), 200);
    }
    if (req.method == 'GET' && path == '/categories') {
      return http.Response(
        jsonEncode([
          {'id': 'c1', 'name': 'Comida', 'kind': 'expense'},
        ]),
        200,
      );
    }
    if (req.method == 'POST' && path == '/categories') {
      return http.Response(jsonEncode({...jsonDecode(req.body) as Map, 'id': 'c${nextId++}'}), 201);
    }
    if (req.method == 'POST' && path == '/transactions') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['account_id'] == 'gone') {
        return http.Response(
          jsonEncode({
            'error': {'code': 'not_found', 'message': 'x'},
          }),
          404,
        );
      }
      final t = {...body, 'id': 't${nextId++}'};
      txs.insert(0, t);
      return http.Response(jsonEncode(t), 201);
    }
    if (req.method == 'DELETE' && path.startsWith('/transactions/')) {
      txs.removeWhere((t) => t['id'] == path.split('/').last);
      return http.Response('', 204);
    }
    return http.Response('{}', 200);
  });
}

void main() {
  late SharedPreferences prefs;
  late FakeServer server;
  late ApiClient api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    server = FakeServer();
    ApiClient.retryDelays = const [];
    api = ApiClient(prefs, client: server.client, baseUrl: 'http://x');
  });

  Map<String, dynamic> newTx(String description, {String account = 'a1'}) => {
    'type': 'expense',
    'account_id': account,
    'amount': '5',
    'description': description,
    'occurred_on': '2026-11-02',
  };

  test('sin conexión se ven los últimos datos leídos', () async {
    final live = await api.get('/transactions', query: {'limit': 20, 'offset': 0}) as Map;
    expect((live['items'] as List).single['id'], 't1');
    server.online = false;
    final cached = await api.get('/transactions', query: {'offset': 0, 'limit': 20}) as Map;
    expect((cached['items'] as List).single['description'], 'Pan');
    expect(api.reachable.value, isFalse);
    expect(api.loadError.value, isNull); // nada de «no pudimos cargar»: hay datos guardados
  });

  test('sin datos guardados el fallo se avisa como antes', () async {
    server.online = false;
    await expectLater(api.get('/goals'), throwsA(isA<ApiError>()));
    expect(api.loadError.value, isNotNull);
  });

  test('un movimiento creado sin conexión se ve al momento como pendiente', () async {
    await api.get('/transactions', query: {'offset': 0});
    server.online = false;
    final res = await api.post('/transactions', body: newTx('Café')) as Map;
    expect(res['id'], startsWith(tempPrefix));
    expect(api.outbox.count.value, 1);
    final page = await api.get('/transactions', query: {'offset': 0}) as Map;
    final items = page['items'] as List;
    expect(items.first['description'], 'Café');
    expect(items.first['pending'], isTrue);
    expect(page['total'], 2);
  });

  test('al volver la conexión se envía en orden, con clave de idempotencia y el id real', () async {
    server.online = false;
    // Categoría nueva sin conexión y un gasto que la usa: el gasto debe llegar con el id real
    final cat = await api.post('/categories', body: {'name': 'Mascotas', 'kind': 'expense'}) as Map;
    await api.post('/transactions', body: {...newTx('Pienso'), 'category_id': cat['id']});
    expect(api.outbox.items.length, 2);

    server.online = true;
    final r = await api.flushOutbox();
    expect(r.sent, 2);
    expect(api.outbox.isEmpty, isTrue);
    final posts = server.requests.where((q) => q.method == 'POST').toList();
    expect(posts.map((q) => q.url.path), ['/api/v1/categories', '/api/v1/transactions']);
    expect(posts.every((q) => q.headers['Idempotency-Key']?.isNotEmpty ?? false), isTrue);
    final sentTx = jsonDecode(posts.last.body) as Map;
    expect(sentTx['category_id'], startsWith('c'));
    expect(sentTx['category_id'], isNot(startsWith(tempPrefix)));
  });

  test('editar o borrar algo creado sin conexión no manda pasos de más', () async {
    server.online = false;
    final t = await api.post('/transactions', body: newTx('Té')) as Map;
    await api.call('PUT', '/transactions/${t['id']}', body: {...newTx('Té verde')});
    expect(api.outbox.items.single.method, 'POST');
    expect((api.outbox.items.single.body as Map)['description'], 'Té verde');
    await api.delete('/transactions/${t['id']}');
    expect(api.outbox.isEmpty, isTrue);
  });

  test('borrar sin conexión oculta el movimiento y se borra al sincronizar', () async {
    await api.get('/transactions');
    server.online = false;
    await api.delete('/transactions/t1');
    final page = await api.get('/transactions') as Map;
    expect(page['items'], isEmpty);
    server.online = true;
    await api.flushOutbox();
    expect(server.txs, isEmpty);
  });

  test('lo que el servidor rechaza se descarta sin bloquear lo demás', () async {
    server.online = false;
    await api.post('/transactions', body: newTx('Fantasma', account: 'gone'));
    await api.post('/transactions', body: newTx('Bueno'));
    server.online = true;
    final r = await api.flushOutbox();
    expect(r.sent, 1);
    expect(r.rejected, 1);
    expect(server.txs.first['description'], 'Bueno');
  });

  test('un corte durante el envío deja el resto en la cola', () async {
    server.online = false;
    await api.post('/transactions', body: newTx('Uno'));
    final r = await api.flushOutbox();
    expect(r.stopped, isTrue);
    expect(api.outbox.count.value, 1);
  });

  test('con cambios en cola, los nuevos van detrás aunque haya conexión', () async {
    server.online = false;
    await api.post('/transactions', body: newTx('Primero'));
    server.online = true;
    await api.post('/transactions', body: newTx('Segundo'));
    expect(api.outbox.items.length, 2);
    await api.flushOutbox();
    expect(server.txs.take(2).map((t) => t['description']), ['Segundo', 'Primero']);
  });

  test('la cola antigua del recuadro rápido se conserva', () async {
    SharedPreferences.setMockInitialValues({
      'pending_transactions': jsonEncode([newTx('Del recuadro')]),
    });
    final p = await SharedPreferences.getInstance();
    final outbox = Outbox(p);
    expect(outbox.items.single.path, '/transactions');
    expect(p.getString('pending_transactions'), isNull);
  });

  test('las rutas de sesión y seguridad nunca se encolan', () {
    expect(isQueueable('POST', '/auth/login'), isFalse);
    expect(isQueueable('POST', '/recurring/run'), isFalse);
    expect(isQueueable('DELETE', '/auth/me'), isFalse);
    expect(isQueueable('POST', '/transactions'), isTrue);
    expect(isQueueable('PATCH', '/accounts/a1'), isTrue);
    expect(isQueueable('PUT', '/life-hours/profile'), isTrue);
  });

  test('el filtro de la lista decide si se ve lo creado sin conexión', () {
    final op = OutboxItem(id: 'x', method: 'POST', path: '/transactions', body: newTx('Cine'), tempId: '${tempPrefix}ab');
    final page = {'items': <Object>[], 'total': 0};
    expect((applyOverlay([op], '/transactions', {'search': 'cin'}, page) as Map)['total'], 1);
    expect((applyOverlay([op], '/transactions', {'date_from': '2026-12-01'}, page) as Map)['total'], 0);
    expect((applyOverlay([op], '/transactions', {'offset': '20'}, page) as Map)['total'], 0);
  });
}
