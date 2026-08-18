import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
        _parseResponseMessage(
          response,
          'Error ${response.statusCode} al obtener perfil',
        ),
      );
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
          'Error ${response.statusCode} al obtener ubicación',
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
    String? estadoPublicacion,
    String? imagenArticulo,
  }) async {
    final payload = <String, dynamic>{};
    if (titulo != null) payload['titulo'] = titulo;
    if (contenido != null) payload['contenido'] = contenido;
    if (autor != null) payload['autor'] = autor;
    if (categoria != null) payload['categoria'] = categoria;
    if (estadoPublicacion != null)
      payload['estado_publicacion'] = estadoPublicacion;
    if (imagenArticulo != null) payload['imagen_articulo'] = imagenArticulo;

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

  void dispose() {
    _client.close();
  }
}
