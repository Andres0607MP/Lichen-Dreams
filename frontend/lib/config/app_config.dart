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

  static String getImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath =
        imagePath.startsWith('/') ? imagePath : '/$imagePath';

    final result = '$normalizedBase$normalizedPath';
    assert(() {
      print('[AppConfig.getImageUrl] input: "$imagePath" -> output: "$result"');
      return true;
    }());
    return result;
  }

  static bool isPrivateImagePath(String imagePath) {
    final normalized = imagePath.trim();
    return normalized.contains('/uploads/profiles/') ||
        normalized.contains('/uploads/analyses/');
  }
}
