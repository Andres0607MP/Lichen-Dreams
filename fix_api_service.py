with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\services\api_service.dart', 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()

old_code = """Future<List<Map<String, dynamic>>> getLiquenpediaArticles() async {
    return await _call(() async {
    final response = await _client.get(
      AppConfig.buildUri('/liquenpedia'),
      headers: await _headers(authorized: true),
    ).timeout(const Duration(seconds: 10));
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
    });
  }"""

new_code = """Future<List<Map<String, dynamic>>> getLiquenpediaArticles({int? skip, int? limit}) async {
    return await _call(() async {
      final queryParams = <String, String>{};
      if (skip != null) queryParams['skip'] = skip.toString();
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = AppConfig.buildUri('/liquenpedia', queryParams: queryParams);

      final response = await _client.get(
        uri,
        headers: await _headers(authorized: true),
      ).timeout(const Duration(seconds: 10));
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
    });
  }"""

if old_code in content:
    content = content.replace(old_code, new_code)
    with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\services\api_service.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS: File updated")
else:
    print("ERROR: Old code not found")
    idx = content.find("getLiquenpediaArticles")
    if idx >= 0:
        print("Found at index:", idx)
        print("Context:", repr(content[idx:idx+500]))