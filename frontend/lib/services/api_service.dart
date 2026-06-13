import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userRoleKey = 'user_role';

  String _parseResponseMessage(Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            fallback;
      }
    } catch (_) {
      return fallback;
    }
    return fallback;
  }

  Future<String> testConnection() async {
    final candidates = [
      AppConfig.buildUri('/api/test'),
      AppConfig.buildUri('/'),
    ];

    Object? lastError;

    for (final uri in candidates) {
      try {
        final response = await _client.get(uri).timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded['message']?.toString() ??
                'Backend conectado correctamente';
          }

          return 'Backend conectado correctamente';
        }

        throw ApiException(_parseResponseMessage(
          response,
          'El backend respondió con código ${response.statusCode}',
        ));
      } on ApiException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }

    throw ApiException('No fue posible conectar con el backend: $lastError');
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(AppConfig.buildUri(path));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al consumir $path',
      ));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{'data': decoded};
  }

  Future<Map<String, String>> _headers({bool authorized = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (authorized) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> getProtectedJson(String path) async {
    final response = await _client.get(
      AppConfig.buildUri(path),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al consumir $path',
      ));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getUsers() async {
    final response = await _client.get(
      AppConfig.buildUri('/admin/users'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al consumir /admin/users',
      ));
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> deleteUser(int id) async {
    final response = await _client.delete(
      AppConfig.buildUri('/admin/users/$id'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 204) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al eliminar usuario',
      ));
    }
  }

  Future<Map<String, dynamic>> updateUser(
    int id, {
    String? email,
    String? name,
    String? phone,
    bool? active,
  }) async {
    final payload = <String, dynamic>{};
    if (email != null) payload['email'] = email;
    if (name != null) payload['name'] = name;
    if (phone != null) payload['phone'] = phone;
    if (active != null) payload['active'] = active;

    final response = await _client.put(
      AppConfig.buildUri('/admin/users/$id'),
      headers: await _headers(authorized: true),
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al actualizar usuario',
      ));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Login con email y contraseña
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _client
          .post(
            AppConfig.buildUri('/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['access_token'] != null) {
          await _saveToken(data['access_token']);
        }
        if (data['refresh_token'] != null) {
          await _saveRefreshToken(data['refresh_token']);
        }
        if (data['user'] is Map<String, dynamic>) {
          final role = (data['user'] as Map<String, dynamic>)['rol'];
          if (role is String) {
            await _saveUserRole(role);
          }
        }
        return data;
      }

      if (response.statusCode == 401) {
        throw ApiException('Email o contraseña incorrectos');
      }

      throw ApiException(_parseResponseMessage(
        response,
        'Error en autenticación: ${response.statusCode}',
      ));
    } on http.ClientException catch (error) {
      throw ApiException('Error de conexión: ${error.message}');
    } on Exception catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Error de conexión: ${error.toString()}');
    }
  }

  /// Registro de nuevo usuario
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password, {
    String? apellido,
    String? phone,
    String? tipoDocumento,
    String? numeroDocumento,
    String? fechaNacimiento,
  }) async {
    try {
      final response = await _client
          .post(
            AppConfig.buildUri('/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'apellido': apellido,
              'phone': phone,
              'tipo_documento': tipoDocumento,
              'numero_documento': numeroDocumento,
              'fecha_nacimiento': fechaNacimiento,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw ApiException(_parseResponseMessage(
        response,
        'Error en registro: ${response.statusCode}',
      ));
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Error al registrarse: ${error.toString()}');
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

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  /// Guardar token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRoleKey, role);
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userRoleKey);
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
    await prefs.remove(_userRoleKey);
  }

  /// Verificar si hay sesión activa
  Future<bool> hasActiveSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Obtener perfil del usuario autenticado
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _client.get(
      AppConfig.buildUri('/profile'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al obtener perfil',
      ));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Actualizar perfil del usuario autenticado
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _client.put(
      AppConfig.buildUri('/profile'),
      headers: await _headers(authorized: true),
      body: jsonEncode(data),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al actualizar perfil',
      ));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  
  Future<List<Map<String, dynamic>>> getLiquenpediaArticles() async {
    final response = await _client.get(
      AppConfig.buildUri('/liquenpedia'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al obtener artículos',
      ));
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return List<Map<String, dynamic>>.from(
        data.map((item) => item as Map<String, dynamic>),
      );
    }
    return <Map<String, dynamic>>[];
  }

  /// Obtener un artículo específico (público, pero con permiso especial para admin)
  Future<Map<String, dynamic>> getLiquenpediaArticle(int id) async {
    final response = await _client.get(
      AppConfig.buildUri('/liquenpedia/$id'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al obtener artículo',
      ));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Crear nuevo artículo (solo admin)
  Future<Map<String, dynamic>> createLiquenpediaArticle({
    required String titulo,
    required String contenido,
    required String autor,
    required String categoria,
    required String estadoPublicacion,
    String? imagenArticulo,
  }) async {
    final response = await _client.post(
      AppConfig.buildUri('/liquenpedia'),
      headers: await _headers(authorized: true),
      body: jsonEncode({
        'titulo': titulo,
        'contenido': contenido,
        'autor': autor,
        'categoria': categoria,
        'estado_publicacion': estadoPublicacion,
        'imagen_articulo': imagenArticulo,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al crear artículo',
      ));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Actualizar artículo (solo admin)
  Future<Map<String, dynamic>> updateLiquenpediaArticle(
    int id, {
    String? titulo,
    String? contenido,
    String? autor,
    String? categoria,
    String? estadoPublicacion,
    String? imagenArticulo,
  }) async {
    final payload = <String, dynamic>{};
    if (titulo != null) payload['titulo'] = titulo;
    if (contenido != null) payload['contenido'] = contenido;
    if (autor != null) payload['autor'] = autor;
    if (categoria != null) payload['categoria'] = categoria;
    if (estadoPublicacion != null) payload['estado_publicacion'] = estadoPublicacion;
    if (imagenArticulo != null) payload['imagen_articulo'] = imagenArticulo;

    final response = await _client.put(
      AppConfig.buildUri('/liquenpedia/$id'),
      headers: await _headers(authorized: true),
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al actualizar artículo',
      ));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Eliminar artículo (solo admin)
  Future<void> deleteLiquenpediaArticle(int id) async {
    final response = await _client.delete(
      AppConfig.buildUri('/liquenpedia/$id'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ApiException(_parseResponseMessage(
        response,
        'Error ${response.statusCode} al eliminar artículo',
      ));
    }
  }

  void dispose() {
    _client.close();
  }
}

