import 'dart:io';

class AppConfig {
  static final String baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '')
          .isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : _defaultBaseUrl;

  static String get _defaultBaseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static Uri buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }
}
