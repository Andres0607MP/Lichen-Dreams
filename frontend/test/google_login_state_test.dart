import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/google_auth_service.dart';

class MockApiService extends ApiService {
  String? idTokenToFail;
  String? idTokenReceived;
  String? modoReceived;

  @override
  Future<Map<String, dynamic>> loginWithGoogle(
    String idToken, {
    String modo = 'registro',
  }) async {
    idTokenReceived = idToken;
    modoReceived = modo;
    if (idTokenToFail != null && idToken == idTokenToFail) {
      throw ApiException('Token de Google inválido o expirado.');
    }
    return {
      'access_token': 'google_access_token',
      'refresh_token': 'google_refresh_token',
      'user': {'rol': 'user', 'nombre': 'Google User', 'id_usuario': 7},
    };
  }

  @override
  Future<String?> getToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<String?> getSavedRole() async => null;

  @override
  Future<void> clearAuth() async {}
}

class MockGoogleAuthService extends GoogleAuthService {
  String? tokenToReturn;
  bool shouldThrow = false;

  @override
  Future<String?> signInAndGetIdToken() async {
    if (shouldThrow) {
      throw Exception('servicio de Google no disponible');
    }
    return tokenToReturn; // null => el usuario canceló
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthState loginWithGoogle', () {
    test('cancelación devuelve false y no inicia sesión', () async {
      final mockApi = MockApiService();
      final mockGoogle = MockGoogleAuthService()..tokenToReturn = null;
      final authState = AuthState(apiService: mockApi, googleAuth: mockGoogle);

      final success = await authState.loginWithGoogle();

      expect(success, isFalse);
      expect(authState.token, isNull);
      expect(mockApi.idTokenReceived, isNull);
    });

    test('éxito guarda tokens, rol y usuario', () async {
      final mockApi = MockApiService();
      final mockGoogle = MockGoogleAuthService()
        ..tokenToReturn = 'id_token_fake';
      final authState = AuthState(apiService: mockApi, googleAuth: mockGoogle);

      final success = await authState.loginWithGoogle();

      expect(success, isTrue);
      expect(mockApi.idTokenReceived, 'id_token_fake');
      expect(mockApi.modoReceived, 'login');
      expect(authState.token, 'google_access_token');
      expect(authState.refreshToken, 'google_refresh_token');
      expect(authState.role, 'user');
      expect(authState.userName, 'Google User');
      expect(authState.userId, 7);
    });

    test('token inválido en backend propaga el error', () async {
      final mockApi = MockApiService();
      final mockGoogle = MockGoogleAuthService()
        ..tokenToReturn = 'id_token_invalido';
      mockApi.idTokenToFail = 'id_token_invalido';
      final authState = AuthState(apiService: mockApi, googleAuth: mockGoogle);

      await expectLater(
        () => authState.loginWithGoogle(),
        throwsA(isA<ApiException>()),
      );
      expect(authState.token, isNull);
    });

    test('error del servicio de Google se propaga', () async {
      final mockApi = MockApiService();
      final mockGoogle = MockGoogleAuthService()..shouldThrow = true;
      final authState = AuthState(apiService: mockApi, googleAuth: mockGoogle);

      await expectLater(
        () => authState.loginWithGoogle(),
        throwsA(isA<Exception>()),
      );
      expect(authState.token, isNull);
    });

    test('modo registro se envía al backend desde Crear cuenta', () async {
      final mockApi = MockApiService();
      final mockGoogle = MockGoogleAuthService()
        ..tokenToReturn = 'id_token_fake';
      final authState = AuthState(apiService: mockApi, googleAuth: mockGoogle);

      final success = await authState.loginWithGoogle(registrar: true);

      expect(success, isTrue);
      expect(mockApi.modoReceived, 'registro');
    });
  });
}