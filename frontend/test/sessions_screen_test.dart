import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/screens/settings/privacy_settings_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('muestra Desconocido para una sesion legacy sin datos de dispositivo',
      (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/auth/sessions');
      return http.Response(
        jsonEncode([
          {
            'id_sesion': 1,
            'es_actual': true,
            'ip_usuario': '192.0.2.1',
          },
        ]),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });
    final api = ApiService(client: client);
    final authState = AuthState(apiService: api);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthState>.value(value: authState),
          Provider<ApiService>.value(value: api),
        ],
        child: const MaterialApp(home: SessionsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Desconocido'), findsOneWidget);
    expect(find.text('192.0.2.1'), findsOneWidget);
  });
}
