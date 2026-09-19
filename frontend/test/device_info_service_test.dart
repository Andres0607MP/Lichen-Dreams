import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/device_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getOrCreateDeviceId genera y persiste un UUID v4', () async {
    final service = DeviceInfoService();
    final deviceId = await service.getOrCreateDeviceId();

    expect(
      deviceId,
      matches(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('device_id'), deviceId);
  });

  test('getOrCreateDeviceId reutiliza el identificador persistido', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', 'persistent-device-id');
    final service = DeviceInfoService();

    expect(await service.getOrCreateDeviceId(), 'persistent-device-id');
    expect(await service.getOrCreateDeviceId(), 'persistent-device-id');
  });

  test('clearAuth y logout conservan el device_id', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', 'persistent-device-id');
    await prefs.setString('auth_token', 'access-token');
    await prefs.setString('refresh_token', 'refresh-token');
    final client = MockClient((request) async {
      return http.Response('{"message":"ok"}', 200);
    });
    final api = ApiService(client: client);

    await api.clearAuth();
    expect(prefs.getString('device_id'), 'persistent-device-id');

    await api.logout();
    expect(prefs.getString('device_id'), 'persistent-device-id');
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
  });

  test('login y Google login envian headers de dispositivo reutilizados', () async {
    final requests = <http.BaseRequest>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{"access_token":"access-token","refresh_token":"refresh-token"}',
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });
    final api = ApiService(client: client);

    await api.login('user@example.com', 'password');
    await api.loginWithGoogle('google-id-token');

    final login = requests.firstWhere(
      (request) => request.url.path == '/auth/login',
    ) as http.Request;
    final google = requests.firstWhere(
      (request) => request.url.path == '/auth/google',
    ) as http.Request;
    final loginDeviceId = login.headers['X-Device-ID'];
    final googleDeviceId = google.headers['X-Device-ID'];

    expect(loginDeviceId, isNotEmpty);
    expect(googleDeviceId, loginDeviceId);
    expect(login.headers['X-Device-Name'], DeviceInfoService.getDeviceName());
    expect(google.headers['X-Device-Name'], DeviceInfoService.getDeviceName());
    expect(login.bodyFields['email'], 'user@example.com');
    expect(jsonDecode(google.body), {
      'id_token': 'google-id-token',
      'modo': 'registro',
    });
  });
}
