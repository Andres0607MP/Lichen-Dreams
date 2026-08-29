import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthState isolation', () {
    test('login reemplaza token anterior y actualiza rol', () async {
      final mockApi = MockApiService();
      mockApi.tokenToReturn = 'token_usuario_nuevo';
      mockApi.userToReturn = {'rol': 'user', 'nombre': 'Usuario Nuevo'};
      mockApi.savedToken = 'token_admin';
      mockApi.savedRole = 'admin';
      final authState = AuthState(apiService: mockApi);

      await authState.initialize();

      expect(authState.token, 'token_admin');
      expect(authState.role, 'admin');

      final result = await authState.login('nuevo@test.com', 'password');

      expect(result, isTrue);
      expect(authState.token, 'token_usuario_nuevo');
      expect(authState.role, 'user');
      expect(authState.userName, 'Usuario Nuevo');
    });

    test('register limpia sesion anterior', () async {
      final mockApi = MockApiService();
      mockApi.savedToken = 'token_admin';
      mockApi.savedRole = 'admin';
      final authState = AuthState(apiService: mockApi);

      await authState.initialize();

      expect(authState.token, 'token_admin');
      expect(authState.role, 'admin');

      await authState.register(
        name: 'Usuario Nuevo',
        email: 'nuevo@test.com',
        password: 'Test123!',
      );

      expect(authState.token, isNull);
      expect(authState.role, isNull);
      expect(authState.userName, isNull);
    });
  });
}

class MockApiService extends ApiService {
  bool shouldFail = false;
  String? tokenToReturn;
  Map<String, dynamic>? userToReturn;
  String? savedToken;
  String? savedRefreshToken;
  String? savedRole;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (shouldFail) {
      throw Exception('Email o contraseña incorrectos');
    }
    return {
      'access_token': tokenToReturn ?? 'fake_token',
      'refresh_token': 'fake_refresh',
      'user': userToReturn ?? {'rol': 'user', 'nombre': 'Test User'},
    };
  }

  @override
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
    return {
      'id_usuario': 99,
      'correo': email,
      'nombre': name,
      'rol': 'user',
    };
  }

  @override
  Future<String?> getToken() async => savedToken;

  @override
  Future<String?> getRefreshToken() async => savedRefreshToken;

  @override
  Future<String?> getSavedRole() async => savedRole;

  @override
  Future<void> clearAuth() async {
    savedToken = null;
    savedRefreshToken = null;
    savedRole = null;
  }
}
