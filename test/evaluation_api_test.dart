import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tablas/evaluation_api.dart';

void main() {
  test('usa GET, POST, PUT y DELETE con el formato REST esperado', () async {
    final requests = <http.Request>[];
    final api = EvaluationApi(
      client: MockClient((request) async {
        requests.add(request);
        return switch (request.method) {
          'GET' => http.Response(
              '{"data":[{"id":7,"participant":"Grupo A"}]}',
              200,
            ),
          'POST' => http.Response('{"data":{"id":7}}', 201),
          'PUT' => http.Response('{"data":{"id":7}}', 200),
          'DELETE' => http.Response('{"data":{"id":7}}', 200),
          _ => http.Response('', 405),
        };
      }),
    );
    const endpoint =
      'http://localhost/tabla-movil-main/backend/api/evaluaciones.php';
    const record = {'participant': 'Grupo A'};

    try {
      expect((await api.getAll(endpoint)).single['participant'], 'Grupo A');
      expect(await api.create(endpoint, record), 7);
      await api.update(endpoint, 7, record);
      await api.delete(endpoint, 7);

      expect(requests.map((request) => request.method), ['GET', 'POST', 'PUT', 'DELETE']);
      expect(requests[1].headers['Content-Type'], 'application/json');
      expect(jsonDecode(requests[1].body), record);
      expect(requests[2].url.queryParameters['id'], '7');
      expect(requests[3].url.queryParameters['id'], '7');
    } finally {
      api.close();
    }
  });
}