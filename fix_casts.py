import os
import re

lib_dir = 'lib'

def simple_replace(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content

    # match patterns like: `(json['key'] as int?)` -> `(json['key'] as num?)?.toInt()`
    # and `json['key'] as int?` -> `(json['key'] as num?)?.toInt()`
    
    # 1. `(some_expr as int?)`
    content = re.sub(r'\(([^()]+)\s+as\s+int\?\)', r'((\1 as num?)?.toInt())', content)
    
    # 2. `some_expr as int?` (without parens, e.g. `json['team'] as int?`)
    content = re.sub(r'(\b\w+\[[^\]]+\])\s+as\s+int\?', r'(\1 as num?)?.toInt()', content)
    
    # 3. `some_expr as int`
    content = re.sub(r'\(([^()]+)\s+as\s+int\)', r'((\1 as num).toInt())', content)
    content = re.sub(r'(\b\w+\[[^\]]+\])\s+as\s+int\b(?!\?)', r'(\1 as num).toInt()', content)

    # Specific fix for MatchLobby.fromJson
    content = content.replace("team: json['team'] as int? ?? 1,", "team: (json['team'] as num?)?.toInt() ?? 1,")

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed {filepath}")

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            simple_replace(os.path.join(root, file))

print("Done")
