import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';

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

  /// Login con email y contraseña
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _client.post(
        AppConfig.buildUri('/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Guardar tokens
        if (data['access_token'] != null) {
          await _saveToken(data['access_token']);
        }
        if (data['refresh_token'] != null) {
          await _saveRefreshToken(data['refresh_token']);
        }
        
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Email o contraseña incorrectos');
      } else {
        throw Exception('Error en autenticación: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Registro de nuevo usuario
  Future<Map<String, dynamic>> register(
    String nombre,
    String apellido,
    String email,
    String password,
  ) async {
    try {
      final response = await _client.post(
        AppConfig.buildUri('/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'apellido': apellido,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error en registro: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al registrarse: $e');
    }
  }

  /// Obtener token guardado
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Obtener refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// Guardar token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Guardar refresh token
  Future<void> _saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  /// Cerrar sesión
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  /// Verificar si hay sesión activa
  Future<bool> hasActiveSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  void dispose() {
    _client.close();
  }
}

