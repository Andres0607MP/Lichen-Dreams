with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\services\api_service.dart', 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()

# Find the function and replace it
import re

# Pattern to match the function (with the special char issue)
pattern = r"(Future<List<Map<String, dynamic>>> getLiquenpediaArticles\(\) async \{\s*return await _call\(\(\) async \{\s*final response = await _client\.get\(\s*AppConfig\.buildUri\('/liquenpedia'\),\s*headers: await _headers\(authorized: true\),\s*\)\.timeout\(const Duration\(seconds: 10\)\);\s*if \(response\.statusCode < 200 \|\| response\.statusCode >= 300\) \{\s*throw ApiException\(\s*_parseResponseMessage\(\s*response,\s*'Error \$\{response\.statusCode\} al obtener art[^']*culos',\s*\),\s*\);\s*\}\s*final data = jsonDecode\(response\.body\);\s*if \(data is List\) \{\s*final list = List<Map<String, dynamic>>\.from\(\s*data\.map\(\(item\) => item as Map<String, dynamic>\),\s*\);\s*for \(final item in list\) \{\s*_normalizeImageUrl\(item\);\s*\}\s*return list;\s*\}\s*return <Map<String, dynamic>>\[\];\s*\}\);\s*\})"

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

new_content = re.sub(pattern, new_code, content, flags=re.DOTALL)

if new_content != content:
    with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\services\api_service.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("SUCCESS: File updated")
else:
    print("ERROR: Pattern not matched")