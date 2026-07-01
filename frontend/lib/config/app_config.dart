import 'platform_url_stub.dart'
    if (dart.library.html) 'platform_url_web.dart'
    if (dart.library.io) 'platform_url_io.dart';

class AppConfig {
  static final String baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '')
          .isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
  : getDefaultBaseUrl();

  static Uri buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }
}
