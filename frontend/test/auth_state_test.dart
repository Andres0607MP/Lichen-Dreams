import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/auth_state.dart';

class MockApiService extends ApiService {
  bool shouldFail = false;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (shouldFail) {
      throw Exception('Email o contraseña incorrectos');
    }
    return {
      'access_token': 'fake_token',
      'refresh_token': 'fake_refresh',
      'user': {
        'rol': 'user',
        'nombre': 'Test User',
      }
    };
  }
}

void main() {
  group('AuthState login', () {
    test('loading se detiene cuando login falla con excepcion', () async {
      final mockApi = MockApiService();
      mockApi.shouldFail = true;
      final authState = AuthState(apiService: mockApi);

      // Esperar a que el Future complete y capture la excepcion
      expectLater(() async => await authState.login('test@example.com', 'wrong'),
          throwsA(isA<Exception>()));

      // Dar tiempo a que el finally se ejecute
      await Future.delayed(const Duration(milliseconds: 100));

      // El loading debe ser false despues del error
      expect(authState.loading, isFalse);
    });

    test('loading se detiene cuando login es exitoso', () async {
      final mockApi = MockApiService();
      mockApi.shouldFail = false;
      final authState = AuthState(apiService: mockApi);

      final result = await authState.login('test@example.com', 'correct');

      expect(result, isTrue);
      expect(authState.loading, isFalse);
    });
  });
}
