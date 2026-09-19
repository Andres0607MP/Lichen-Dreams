import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/routes/route_names.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/connectivity_service.dart';
import 'package:frontend/state/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ConnectivityService backend health', () {
    test(
      'reintenta respuestas 5xx y considera disponible una respuesta exitosa',
      () async {
        var attempts = 0;
        final client = MockClient((request) async {
          attempts++;
          expect(request.url.path, '/api/test');
          if (attempts < 3) {
            return http.Response('', 503);
          }
          return http.Response('', 200);
        });
        final service = ConnectivityService(
          client: client,
          startMonitoring: false,
        );
        final retryingProgress = <bool>[];

        final available = await service.checkBackendWithRetry(
          timeout: const Duration(milliseconds: 100),
          maxAttempts: 3,
          backoffs: const [
            Duration(milliseconds: 1),
            Duration(milliseconds: 1),
          ],
          onProgress: (attempt, maxAttempts, retrying) {
            retryingProgress.add(retrying);
          },
        );

        expect(available, isTrue);
        expect(attempts, 3);
        expect(retryingProgress, [false, true, true]);
      },
    );

    test(
      'agota los intentos cuando el backend sigue respondiendo 5xx',
      () async {
        var attempts = 0;
        final client = MockClient((request) async {
          attempts++;
          return http.Response('', 503);
        });
        final service = ConnectivityService(
          client: client,
          startMonitoring: false,
        );

        final available = await service.checkBackendWithRetry(
          timeout: const Duration(milliseconds: 100),
          maxAttempts: 3,
          backoffs: const [
            Duration(milliseconds: 1),
            Duration(milliseconds: 1),
          ],
        );

        expect(available, isFalse);
        expect(attempts, 3);
      },
    );

    test(
      'considera disponible una respuesta 401 del endpoint de health',
      () async {
        final client = MockClient((_) async => http.Response('', 401));
        final service = ConnectivityService(
          client: client,
          startMonitoring: false,
        );

        expect(await service.checkBackendWithRetry(), isTrue);
      },
    );
  });

  group('AuthState bootstrap', () {
    testWidgets(
      'muestra error y permanece en loading cuando el backend no responde',
      (tester) async {
        final api = BootstrapApiService();
        final connectivity = FakeConnectivityService(false);
        final authState = AuthState(
          apiService: api,
          connectivityService: connectivity,
        );
        final context = await _pumpBootstrapContext(tester);

        await authState.bootstrapAndDecide(context);

        expect(authState.bootstrapStatus, BootstrapStatus.error);
        expect(authState.bootstrapMessage, contains('No pudimos conectar'));
        expect(connectivity.calls, 1);
        expect(find.byKey(_homeKey), findsOneWidget);
      },
    );

    testWidgets('navega a login cuando el backend esta disponible sin token', (
      tester,
    ) async {
      final api = BootstrapApiService();
      final connectivity = FakeConnectivityService(true);
      final authState = AuthState(
        apiService: api,
        connectivityService: connectivity,
      );
      final context = await _pumpBootstrapContext(tester);

      await authState.bootstrapAndDecide(context);
      await tester.pumpAndSettle();

      expect(authState.isAuthenticated, isFalse);
      expect(api.clearAuthCalls, 1);
      expect(find.byKey(_loginKey), findsOneWidget);
    });

    testWidgets('navega a dashboard cuando el backend valida el token', (
      tester,
    ) async {
      final api = BootstrapApiService()..savedToken = 'valid-token';
      final connectivity = FakeConnectivityService(true);
      final authState = AuthState(
        apiService: api,
        connectivityService: connectivity,
      );
      final context = await _pumpBootstrapContext(tester);

      await authState.initialize();
      await authState.bootstrapAndDecide(context);
      await tester.pumpAndSettle();

      expect(api.getMeCalls, 1);
      expect(authState.isAuthenticated, isTrue);
      expect(_lastRouteObserver?.pushedRoute, AppRoutes.dashboard);
      expect(find.byKey(_dashboardKey), findsOneWidget);
    });

    testWidgets(
      'limpia la sesion y navega a login cuando el token devuelve 401',
      (tester) async {
        final api = BootstrapApiService()
          ..savedToken = 'expired-token'
          ..sessionValid = false;
        final connectivity = FakeConnectivityService(true);
        final authState = AuthState(
          apiService: api,
          connectivityService: connectivity,
        );
        final context = await _pumpBootstrapContext(tester);

        await authState.initialize();
        await authState.bootstrapAndDecide(context);
        await tester.pumpAndSettle();

        expect(api.getMeCalls, 1);
        expect(api.clearAuthCalls, 1);
        expect(authState.isAuthenticated, isFalse);
        expect(_lastRouteObserver?.pushedRoute, AppRoutes.login);
        expect(find.byKey(_loginKey), findsOneWidget);
      },
    );
  });
}

const _homeKey = ValueKey('bootstrap-home');
const _loginKey = ValueKey('bootstrap-login');
const _dashboardKey = ValueKey('bootstrap-dashboard');
RouteTrackingObserver? _lastRouteObserver;

class RouteTrackingObserver extends NavigatorObserver {
  String? pushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoute = route.settings.name;
  }
}

Future<BuildContext> _pumpBootstrapContext(WidgetTester tester) async {
  BuildContext? context;
  final routeObserver = RouteTrackingObserver();
  _lastRouteObserver = routeObserver;
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [routeObserver],
      routes: {
        AppRoutes.login: (_) => const Scaffold(key: _loginKey),
        AppRoutes.dashboard: (_) => const Scaffold(key: _dashboardKey),
      },
      home: Builder(
        builder: (builderContext) {
          context = builderContext;
          return const Scaffold(key: _homeKey);
        },
      ),
    ),
  );
  return context!;
}

class FakeConnectivityService extends ConnectivityService {
  FakeConnectivityService(this.available) : super(startMonitoring: false);

  final bool available;
  int calls = 0;

  @override
  Future<bool> checkBackendWithRetry({
    Duration timeout = const Duration(seconds: 15),
    int maxAttempts = 3,
    List<Duration> backoffs = const [
      Duration(seconds: 5),
      Duration(seconds: 10),
    ],
    BackendHealthProgressCallback? onProgress,
  }) async {
    calls++;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      onProgress?.call(attempt, maxAttempts, attempt > 1);
    }
    return available;
  }
}

class BootstrapApiService extends ApiService {
  String? savedToken;
  String? savedRefreshToken = 'refresh-token';
  String? savedRole = 'user';
  bool sessionValid = true;
  int clearAuthCalls = 0;
  int getMeCalls = 0;

  @override
  Future<String?> getToken() async => savedToken;

  @override
  Future<String?> getRefreshToken() async => savedRefreshToken;

  @override
  Future<String?> getSavedRole() async => savedRole;

  @override
  Future<Map<String, dynamic>> getMe() async {
    getMeCalls++;
    if (!sessionValid) {
      throw ApiException('Token invalido', 401);
    }
    return {
      'id_usuario': 1,
      'nombre': 'Test User',
      'rol': 'user',
      'proveedor': 'local',
    };
  }

  @override
  Future<void> clearAuth() async {
    clearAuthCalls++;
    savedToken = null;
    savedRefreshToken = null;
    savedRole = null;
  }
}
