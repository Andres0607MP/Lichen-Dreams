import re

with open('frontend/lib/services/api_service.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Check first few lines for method patterns
method_pattern = re.compile(r'^\s+(?:Future<(?:\w+<[^>]+)>|Future|void|int|String|bool|List|<\w+>)\s+(\w+)\s*\(')
count = 0
for i, line in enumerate(lines[:100]):
    stripped = line.lstrip()
    if 'async {' in stripped:
        match = method_pattern.match(stripped)
        if match:
            count += 1
            print(f"{i+1}: {match.group(1)} - matched")
        else:
            print(f"{i+1}: {stripped[:60]} - NO MATCH")
print(f"\nTotal matches: {count}")
