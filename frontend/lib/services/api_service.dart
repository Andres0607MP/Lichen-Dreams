import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> testConnection() async {
    final candidates = [
      AppConfig.buildUri('/api/test'),
      AppConfig.buildUri('/'),
    ];

    Object? lastError;

    for (final uri in candidates) {
      try {
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded['message']?.toString() ??
                'Backend conectado correctamente';
          }

          return 'Backend conectado correctamente';
        }
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception('No fue posible conectar con el backend: $lastError');
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(AppConfig.buildUri(path));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error ${response.statusCode} al consumir $path');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{'data': decoded};
  }

  void dispose() {
    _client.close();
  }
}
