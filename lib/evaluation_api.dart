import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente REST: Flutter envía solicitudes a PHP; PHP valida y accede a MySQL.
class EvaluationApi {
  EvaluationApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // GET consulta las evaluaciones guardadas en la base de datos.
  Future<List<Map<String, dynamic>>> getAll(String endpoint) async {
    final response = await _client.get(Uri.parse(endpoint));
    final payload = _decode(response);
    final records = (payload as Map<String, dynamic>)['data'] as List<dynamic>;
    return records
        .map((record) => Map<String, dynamic>.from(record as Map))
        .toList();
  }

  // POST crea un registro y devuelve el identificador generado por MySQL.
  Future<int> create(String endpoint, Map<String, dynamic> record) async {
    final response = await _client.post(
      Uri.parse(endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(record),
    );
    final payload = _decode(response) as Map<String, dynamic>;
    return (payload['data'] as Map<String, dynamic>)['id'] as int;
  }

  // PUT actualiza el registro identificado por el parámetro id.
  Future<void> update(
    String endpoint,
    int id,
    Map<String, dynamic> record,
  ) async {
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {...Uri.parse(endpoint).queryParameters, 'id': '$id'},
    );
    final response = await _client.put(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(record),
    );
    _decode(response);
  }

  // DELETE elimina el registro identificado por el parámetro id.
  Future<void> delete(String endpoint, int id) async {
    final parsedEndpoint = Uri.parse(endpoint);
    final uri = parsedEndpoint.replace(
      queryParameters: {...parsedEndpoint.queryParameters, 'id': '$id'},
    );
    final response = await _client.delete(uri);
    _decode(response);
  }

  void close() => _client.close();

  dynamic _decode(http.Response response) {
    final payload = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Map<String, dynamic>
          ? payload['error']?.toString()
          : null;
      throw Exception(message ?? 'Error HTTP ${response.statusCode}');
    }
    return payload;
  }
}
