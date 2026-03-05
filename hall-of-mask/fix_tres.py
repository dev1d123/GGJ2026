import re

file_path = 'c:/Users/DrN/UNSA/PROYECTOS/GGJ26/GGJ2026/hall-of-mask/src/actors/enemies/bosses/skull_knight.tres'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find all IDs
ids = re.findall(r'id=\"(AnimationNode[^\"]+)\"', content)
unique_ids = set(ids)

for old_id in unique_ids:
    new_id = old_id + '_skull'
    content = content.replace(f'id=\"{old_id}\"', f'id=\"{new_id}\"')
    content = content.replace(f'SubResource(\"{old_id}\")', f'SubResource(\"{new_id}\")')
    
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'Replaced {len(unique_ids)} unique IDs in {file_path}')
