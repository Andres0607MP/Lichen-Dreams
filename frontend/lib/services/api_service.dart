import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          final mensajes = detail
              .whereType<Map>()
              .map((e) => e['msg']?.toString())
              .whereType<String>()
              .where((m) => m.isNotEmpty)
              .toList();
          if (mensajes.isNotEmpty) {
            return mensajes.join('\n');
          }
        }
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
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

        throw ApiException(
          _parseResponseMessage(
            response,
            'El backend respondió con código ${response.statusCode}',
          ),
        );
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
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al consumir $path',
        ),
      );
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
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al consumir $path',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postProtectedJson(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      AppConfig.buildUri(path),
      headers: await _headers(authorized: true),
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al consumir $path',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getUsers() async {
    final response = await _client.get(
      AppConfig.buildUri('/admin/users'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al consumir /admin/users',
        ),
      );
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> deleteUser(int id) async {
    final response = await _client.delete(
      AppConfig.buildUri('/admin/users/$id'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 204) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al eliminar usuario',
        ),
      );
    }
  }

  /// Subir imagen para LiquenPedia o perfil desde el dispositivo
  Future<String> uploadImage(File imageFile, {String imageType = 'article'}) async {
    final uri = AppConfig.buildUri('/imagenes/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(authorized: true));
    request.fields['imagen_tipo'] = imageType;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: imageFile.path.split(Platform.pathSeparator).last,
      ),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al subir imagen',
        ),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      _normalizeImageUrl(decoded);
      return decoded['url']?.toString() ??
          decoded['data']?['url']?.toString() ??
          '';
    }

    throw ApiException('Respuesta inesperada al subir imagen');
  }

  /// Subir imagen de referencia para una especie de liquen.
  Future<String> uploadSpeciesImage(File imageFile) async {
    return uploadImage(imageFile, imageType: 'species');
  }

  /// Descargar imagen: URLs remotas (http/https, p. ej. lh3.googleusercontent.com)
  /// se obtienen directamente; rutas privadas locales (/uploads/...) usan el
  /// endpoint autenticado del backend.
  Future<Uint8List> downloadImageBytes(String imagePath) async {
    final normalized = imagePath.trim();
    if (normalized.startsWith('http://') ||
        normalized.startsWith('https://')) {
      final response = await _client.get(Uri.parse(normalized));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Error ${response.statusCode} al descargar imagen externa',
        );
      }
      return response.bodyBytes;
    }
    return downloadPrivateImageBytes(normalized);
  }

  /// Descargar imagen privada (profiles/ o analyses/) con token de auth
  Future<Uint8List> downloadPrivateImageBytes(String imagePath) async {
    final normalized = imagePath.trim();
    if (!normalized.startsWith('/uploads/')) {
      throw ApiException('Path de imagen invalido: $imagePath');
    }
    final fileSubpath = normalized.substring('/uploads/'.length);
    final uri = AppConfig.buildUri('/imagenes/file/$fileSubpath');

    final response = await _client.get(
      uri,
      headers: await _headers(authorized: true),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al descargar imagen',
        ),
      );
    }

    return Uint8List.fromList(response.bodyBytes);
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
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al actualizar usuario',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Login con email y contraseña
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final uri = AppConfig.buildUri('/auth/login');
      final request = http.Request('POST', uri);
      request.headers.addAll(await _headers(authorized: false));
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
      request.bodyFields = {'email': email, 'password': password};

      final responseStream = await _client.send(request).timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(responseStream);

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

      throw ApiException(
        _parseResponseMessage(
          response,
          'Error en autenticación: ${response.statusCode}',
        ),
      );
    } on http.ClientException catch (error) {
      throw ApiException('Error de conexión: ${error.message}');
    } on Exception catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Error de conexión: ${error.toString()}');
    }
  }

  /// Login con el ID token de Google obtenido por google_sign_in
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    try {
      final response = await _client
          .post(
            AppConfig.buildUri('/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 15));

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

      // Diagnóstico temporal [GOOGLE-DEBUG]: el backend devolvió un error;
      // registrar el estado y el cuerpo real para identificar la causa
      // exacta (401 aud/exp/firma vs 503 sin conexión a Google).
      debugPrint('[GOOGLE-DEBUG] POST /auth/google -> ${response.statusCode} '
          'body=${response.body}');

      if (response.statusCode == 401) {
        throw ApiException('La sesión de Google no fue autorizada. Intenta de nuevo.');
      }
      if (response.statusCode == 409) {
        throw ApiException(
          _parseResponseMessage(
            response,
            'Ya existe una cuenta con este correo. Usa tu correo y contraseña.',
          ),
        );
      }
      if (response.statusCode == 503) {
        throw ApiException(
          'El servidor no pudo validar el token de Google. '
          'Verifica que tenga acceso a internet y reintenta.',
        );
      }

      throw ApiException(
        _parseResponseMessage(
          response,
          'Error al iniciar sesión con Google: ${response.statusCode}',
        ),
      );
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

      throw ApiException(
        _parseResponseMessage(
          response,
          'Error en registro: ${response.statusCode}',
        ),
      );
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
      throw ApiException(
        _parseResponseMessage(response, 'Error al obtener el perfil'),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Obtener la información de la sesión actual (/auth/me), incluido el
  /// proveedor de la cuenta ('local' | 'google').
  Future<Map<String, dynamic>> getMe() async {
    final response = await _client.get(
      AppConfig.buildUri('/auth/me'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error al obtener la información del usuario',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getReports() async {
    final response = await _client.get(
      AppConfig.buildUri('/reports'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener reportes',
        ),
      );
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getReport(int reportId) async {
    final response = await _client.get(
      AppConfig.buildUri('/reports/$reportId'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener el reporte',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEnvironmentalReport({
    required String title,
    String? description,
  }) async {
    final response = await _client.post(
      AppConfig.buildUri('/reports/environmental'),
      headers: await _headers(authorized: true),
      body: jsonEncode({
        'titulo': title,
        'descripcion': description,
        'tipo_reporte': 'ambiental',
        'formato_reporte': 'json',
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al generar el reporte ambiental',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Eliminar un reporte propio (DELETE /reports/{id}).
  Future<void> deleteReport(int reportId) async {
    final response = await _client.delete(
      AppConfig.buildUri('/reports/$reportId'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al eliminar el reporte',
        ),
      );
    }
  }

  /// Actualizar perfil del usuario autenticado
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _client.put(
      AppConfig.buildUri('/profile'),
      headers: await _headers(authorized: true),
      body: jsonEncode(data),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al actualizar perfil',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getLiquenpediaArticles() async {
    final response = await _client.get(
      AppConfig.buildUri('/liquenpedia'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener artículos',
        ),
      );
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      final list = List<Map<String, dynamic>>.from(
        data.map((item) => item as Map<String, dynamic>),
      );
      for (final item in list) {
        _normalizeImageUrl(item);
      }
      return list;
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
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener artículo',
        ),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    _normalizeImageUrl(decoded);
    return decoded;
  }

  /// Guardar un análisis en el historial del usuario autenticado
  Future<Map<String, dynamic>> saveHistory(Map<String, dynamic> payload) async {
    final response = await _client.post(
      AppConfig.buildUri('/history/save'),
      headers: await _headers(authorized: true),
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al guardar historial',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Obtener historial de análisis del usuario autenticado
  Future<List<Map<String, dynamic>>> getAnalysisHistory() async {
    final response = await _client.get(
      AppConfig.buildUri('/history'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener historial',
        ),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      final list = List<Map<String, dynamic>>.from(
        decoded.map((item) => item as Map<String, dynamic>),
      );
      for (final item in list) {
        _normalizeImageUrl(item);
      }
      return list;
    }
    if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      final list = List<Map<String, dynamic>>.from(
        (decoded['data'] as List).map((item) => item as Map<String, dynamic>),
      );
      for (final item in list) {
        _normalizeImageUrl(item);
      }
      return list;
    }
    if (decoded is Map<String, dynamic> && decoded['history'] is List) {
      final list = List<Map<String, dynamic>>.from(
        (decoded['history'] as List).map(
          (item) => item as Map<String, dynamic>,
        ),
      );
      for (final item in list) {
        _normalizeImageUrl(item);
      }
      return list;
    }
    throw ApiException('Respuesta inesperada del historial de análisis');
  }

  /// Obtener puntos ambientales para el mapa
  Future<List<Map<String, dynamic>>> getMapPoints() async {
    final response = await _client.get(
      AppConfig.buildUri('/api/maps/points'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener puntos del mapa',
        ),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      final list = List<Map<String, dynamic>>.from(
        decoded.map((item) => item as Map<String, dynamic>),
      );
      return list;
    }
    return <Map<String, dynamic>>[];
  }

  /// Eliminar un registro del historial
  Future<void> deleteHistory(int historyId) async {
    final response = await _client.delete(
      AppConfig.buildUri('/history/$historyId'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 204) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al eliminar historial',
        ),
      );
    }
  }

  /// Eliminar un análisis por su ID
  Future<void> deleteAnalysis(int analysisId) async {
    final response = await _client.delete(
      AppConfig.buildUri('/analysis/$analysisId'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 204) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al eliminar análisis',
        ),
      );
    }
  }

  /// Obtener estadísticas principales para el dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _client.get(
      AppConfig.buildUri('/dashboard/stats'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener estadísticas del dashboard',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Enviar imagen para análisis por backend
  Future<Map<String, dynamic>> submitAnalysis(
    File imageFile, {
    int? id_ubicacion,
    String imageSource = 'camera',
  }) async {
    final uri = AppConfig.buildUri('/analysis/process');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(authorized: true));
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: imageFile.path.split(Platform.pathSeparator).last,
      ),
    );
    if (id_ubicacion != null) {
      request.fields['id_ubicacion'] = id_ubicacion.toString();
    }
    request.fields['image_source'] = imageSource;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al enviar imagen para análisis',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Obtener detalles de un análisis específico
  Future<Map<String, dynamic>> getAnalysisResult(int id) async {
    final response = await _client.get(
      AppConfig.buildUri('/analysis/results/$id'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener resultado',
        ),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    _normalizeImageUrl(decoded);
    return decoded;
  }

  void _normalizeImageUrl(Map<String, dynamic> json) {
    final candidates = [
      'imagen_url',
      'image_url',
      'url_imagen',
      'url',
      'imagen_articulo',
      'foto_perfil_articulo',
    ];
    for (final key in candidates) {
      if (json.containsKey(key) && json[key] is String) {
        var val = (json[key] as String).trim();
        if (val.isEmpty) continue;

        // Absolute URL -> extract relative path (strip scheme + host).
        // This ensures legacy DB records with full URLs (e.g. http://192.168.1.100:8000/uploads/x.jpg)
        // are converted to relative paths (/uploads/x.jpg) so that
        // AppConfig.getImageUrl() can build the URL using the current API_BASE_URL.
        if (val.startsWith('http://') || val.startsWith('https://')) {
          Uri? parsed;
          try {
            parsed = Uri.parse(val);
          } catch (_) {
            parsed = null;
          }
          if (parsed != null && parsed.path.isNotEmpty) {
            final relativePath = parsed.path + (parsed.hasQuery ? '?${parsed.query}' : '');
            json[key] = relativePath;
          }
        }
        // Relative paths (starting with '/') are left unchanged so
        // AppConfig.getImageUrl() can prepend the base URL at the UI layer.
      }
    }
  }

  /// Obtener el estado actual del análisis
  Future<Map<String, dynamic>> getAnalysisStatus(int id) async {
    final response = await _client.get(
      AppConfig.buildUri('/analysis/$id/status'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener estado',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Obtener la humedad asociada a un análisis
  Future<Map<String, dynamic>> getHumidity(int id) async {
    final response = await _client.get(
      AppConfig.buildUri('/analysis/$id/humidity'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener humedad',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Obtener la calidad del aire asociada a un análisis
  Future<Map<String, dynamic>> getAirQuality(int id) async {
    final response = await _client.get(
      AppConfig.buildUri('/analysis/$id/air-quality'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener calidad del aire',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Obtener recomendación asociada a un análisis
  Future<Map<String, dynamic>> getRecommendation(int id) async {
    final response = await _client.get(
      AppConfig.buildUri('/analysis/$id/recommendation'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener recomendación',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSpecies(int analysisId) async {
    final response = await _client.get(
      AppConfig.buildUri('/analysis/$analysisId/species'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener especie',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

Future<Map<String, dynamic>> getAnalysisLocation(int analysisId) async {
    final response = await _client.get(
      AppConfig.buildUri('/analysis/$analysisId/location'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener la ubicación',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Catálogo de especies disponible para usuarios autenticados (lectura).
  Future<List<Map<String, dynamic>>> getCatalogSpecies() async {
    final response = await _client.get(
      AppConfig.buildUri('/catalog/species'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener las especies',
        ),
      );
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Asocia o quita (idEspecie = null) la especie que el usuario seleccionó.
  Future<Map<String, dynamic>> updateAnalysisSpecies(
    int analysisId,
    int? idEspecie,
  ) async {
    final response = await _client.put(
      AppConfig.buildUri('/analysis/$analysisId/species'),
      headers: await _headers(authorized: true),
      body: jsonEncode({'id_especie': idEspecie}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al guardar la especie',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _client.get(
      AppConfig.buildUri('/notificaciones'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener notificaciones',
        ),
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return List<Map<String, dynamic>>.from(
        decoded.map((item) => item as Map<String, dynamic>),
      );
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> clearNotifications() async {
    final response = await _client.delete(
      AppConfig.buildUri('/notificaciones/clear'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al limpiar notificaciones',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> markNotificationRead(int notificationId) async {
    final response = await _client.patch(
      AppConfig.buildUri('/notificaciones/$notificationId/read'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al marcar notificación como leída',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> shareAnalysis(int analysisId) async {
    final response = await _client.post(
      AppConfig.buildUri('/analysis/$analysisId/share'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al compartir análisis',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> createSystemNotification({
    required String titulo,
    required String mensaje,
    required String destino,
    int? idUsuario,
  }) async {
    final payload = <String, dynamic>{
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo_notificacion': 'system',
      'destino': destino,
    };
    if (idUsuario != null) {
      payload['id_usuario'] = idUsuario;
    }
    final response = await _client.post(
      AppConfig.buildUri('/admin/notifications'),
      headers: await _headers(authorized: true),
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al crear notificación',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveLocation(Map<String, dynamic> locationData) async {
    final response = await _client.post(
      AppConfig.buildUri('/location/save'),
      headers: await _headers(authorized: true),
      body: jsonEncode(locationData),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al guardar ubicación',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> findOrCreateLocation({
    required double latitude,
    required double longitude,
    double radiusMeters = 15.0,
    String? direccion,
    String? municipio,
    String? departamento,
    String? pais = 'Colombia',
  }) async {
    final response = await _client.post(
      AppConfig.buildUri('/location/find-or-create'),
      headers: await _headers(authorized: true),
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'direccion': direccion,
        'municipio': municipio,
        'departamento': departamento,
        'pais': pais,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al buscar/crear ubicación',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Crear nuevo artículo (solo admin)
  Future<Map<String, dynamic>> createLiquenpediaArticle({
    required String titulo,
    required String contenido,
    required String autor,
    required String categoria,
    int? idCategoria,
    required String estadoPublicacion,
    String? imagenArticulo,
    String? fotoPerfilAutor,
  }) async {
    final response = await _client.post(
      AppConfig.buildUri('/liquenpedia'),
      headers: await _headers(authorized: true),
      body: jsonEncode({
        'titulo': titulo,
        'contenido': contenido,
        'autor': autor,
        'categoria': categoria,
        'id_categoria': idCategoria,
        'estado_publicacion': estadoPublicacion,
        'imagen_articulo': imagenArticulo,
        'foto_perfil_articulo': fotoPerfilAutor,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al crear artículo',
        ),
      );
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
    int? idCategoria,
    String? estadoPublicacion,
    String? imagenArticulo,
    String? fotoPerfilAutor,
  }) async {
    final payload = <String, dynamic>{};
    if (titulo != null) payload['titulo'] = titulo;
    if (contenido != null) payload['contenido'] = contenido;
    if (autor != null) payload['autor'] = autor;
    if (categoria != null) payload['categoria'] = categoria;
    if (idCategoria != null) payload['id_categoria'] = idCategoria;
    if (estadoPublicacion != null)
      payload['estado_publicacion'] = estadoPublicacion;
    if (imagenArticulo != null) payload['imagen_articulo'] = imagenArticulo;
    if (fotoPerfilAutor != null) payload['foto_perfil_articulo'] = fotoPerfilAutor;

    final response = await _client.put(
      AppConfig.buildUri('/liquenpedia/$id'),
      headers: await _headers(authorized: true),
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al actualizar artículo',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Obtener categorías de artículos
  Future<List<Map<String, dynamic>>> getCategoriasLiquenpedia() async {
    final response = await _client.get(
      AppConfig.buildUri('/categorias-liquenpedia'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener categorías',
        ),
      );
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return List<Map<String, dynamic>>.from(
        data.map((item) => item as Map<String, dynamic>),
      );
    }
    return <Map<String, dynamic>>[];
  }

  /// Eliminar artículo (solo admin)
  Future<void> deleteLiquenpediaArticle(int id) async {
    final response = await _client.delete(
      AppConfig.buildUri('/liquenpedia/$id'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al eliminar artículo',
        ),
      );
    }
  }

  // ==================== ESPECIES DE LÍQUENES (Admin) ====================

  Future<List<dynamic>> getAdminSpecies() async {
    final response = await _client.get(
      AppConfig.buildUri('/admin/species'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al obtener especies'),
      );
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createAdminSpecies(Map<String, dynamic> data) async {
    final response = await _client.post(
      AppConfig.buildUri('/admin/species'),
      headers: await _headers(authorized: true),
      body: jsonEncode(data),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al crear especie'),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAdminSpecies(int id, Map<String, dynamic> data) async {
    final response = await _client.put(
      AppConfig.buildUri('/admin/species/$id'),
      headers: await _headers(authorized: true),
      body: jsonEncode(data),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al actualizar especie'),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteAdminSpecies(int id) async {
    final response = await _client.delete(
      AppConfig.buildUri('/admin/species/$id'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al eliminar especie'),
      );
    }
  }

  // ==================== ZONAS AMBIENTALES (Admin) ====================

  Future<List<dynamic>> getZones() async {
    final response = await _client.get(
      AppConfig.buildUri('/admin/zones'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al obtener zonas'),
      );
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createZone(Map<String, dynamic> data) async {
    final response = await _client.post(
      AppConfig.buildUri('/admin/zones'),
      headers: await _headers(authorized: true),
      body: jsonEncode(data),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al crear zona'),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateZone(int id, Map<String, dynamic> data) async {
    final response = await _client.put(
      AppConfig.buildUri('/admin/zones/$id'),
      headers: await _headers(authorized: true),
      body: jsonEncode(data),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al actualizar zona'),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteZone(int id) async {
    final response = await _client.delete(
      AppConfig.buildUri('/admin/zones/$id'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al eliminar zona'),
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.post(
      AppConfig.buildUri('/auth/change-password'),
      headers: await _headers(authorized: true),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al cambiar contraseña'),
      );
    }
  }

  Future<void> deleteAccount({required String password}) async {
    final response = await _client.delete(
      AppConfig.buildUri('/auth/account'),
      headers: await _headers(authorized: true),
      body: jsonEncode({'password': password}),
    );
    if (response.statusCode != 204) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al eliminar cuenta'),
      );
    }
  }

  Future<List<dynamic>> getMyAnalyses() async {
    final response = await _client.get(
      AppConfig.buildUri('/analysis/my'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al obtener análisis'),
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded;
    }
    return [];
  }

  Future<Map<String, dynamic>> updateAnalysisVisibility(int analysisId, String visibility) async {
    final response = await _client.put(
      AppConfig.buildUri('/analysis/$analysisId/visibility'),
      headers: await _headers(authorized: true),
      body: jsonEncode({'visibilidad': visibility}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al actualizar visibilidad'),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getSessions() async {
    final response = await _client.get(
      AppConfig.buildUri('/auth/sessions'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al obtener sesiones'),
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded;
    }
    return [];
  }

  Future<void> revokeSession(int sessionId) async {
    final response = await _client.delete(
      AppConfig.buildUri('/auth/sessions/$sessionId'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode != 204) {
      throw ApiException(
        _parseResponseMessage(response, 'Error ${response.statusCode} al revocar sesión'),
      );
    }
  }

  /// Solicitar código de recuperación de contraseña
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _client.post(
      AppConfig.buildUri('/auth/forgot-password'),
      headers: await _headers(authorized: false),
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al solicitar recuperación',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Restablecer contraseña con código de recuperación
  Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    final response = await _client.post(
      AppConfig.buildUri('/auth/reset-password'),
      headers: await _headers(authorized: false),
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al restablecer contraseña',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Recuperar contraseña usando el código de recuperación de un solo uso
  Future<Map<String, dynamic>> recoverWithCode(String code, String newPassword) async {
    final response = await _client.post(
      AppConfig.buildUri('/auth/recover-with-code'),
      headers: await _headers(authorized: false),
      body: jsonEncode({'code': code, 'new_password': newPassword}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al recuperar la cuenta',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Generar un nuevo código de recuperación para el usuario autenticado
  Future<Map<String, dynamic>> regenerateRecoveryCode() async {
    final response = await _client.post(
      AppConfig.buildUri('/auth/recovery-code/regenerate'),
      headers: await _headers(authorized: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al generar el código de recuperación',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Verificar correo electrónico con código de verificación
  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final response = await _client.post(
      AppConfig.buildUri('/auth/verify-email'),
      headers: await _headers(authorized: false),
      body: jsonEncode({'token': token}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al verificar correo',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Reenviar código de verificación
  Future<Map<String, dynamic>> resendVerification(String email) async {
    final response = await _client.post(
      AppConfig.buildUri('/auth/resend-verification'),
      headers: await _headers(authorized: false),
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al reenviar código',
        ),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void dispose() {
    _client.close();
  }
}
