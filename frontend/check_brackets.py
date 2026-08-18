import re
with open('lib/screens/map_screen.dart', encoding='utf-8') as f:
    text = f.read()

pattern = re.compile(r'\"\"\"(?:[^\"\\]|\\.)*\"\"\"|\'\'\'(?:[^\'\\]|\\.)*\'\'\'|\'[^\']*\'|\"[^\"]*\"|//.*|/\*.*?\*/', re.DOTALL)
clean = pattern.sub('', text)

stack = []
for i, ch in enumerate(clean):
    if ch == '[':
        stack.append(('OPEN', i+1))
    elif ch == ']':
        if not stack:
            print(f'Unexpected ] at line {clean[:i].count(chr(10))+1}')
            break
        stack.pop()

if stack:
    print('Unclosed brackets:')
    for token, pos in stack:
        line = clean[:pos].count(chr(10))+1
        print(f'  {token} at line {line}')
else:
    print('All brackets balanced')
