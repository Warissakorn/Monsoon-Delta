#!/usr/bin/env python3
"""Refresh the complete, Git-tracked file index on the repository homepage."""
import argparse
from collections import defaultdict
from pathlib import Path
import re
import subprocess
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
START = '<!-- project-file-index:start -->'
END = '<!-- project-file-index:end -->'
RAW = 'https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/'


def describe(path):
    file = ROOT / path
    suffix = file.suffix
    if suffix == '.md':
        for line in file.read_text(encoding='utf-8').splitlines():
            if line.startswith('# '):
                title = re.sub(r'\[([^]]+)\]\([^)]*\)', r'\1', line[2:])
                return title.replace('|', '/').replace('`', '')
    kinds = {'.gd': 'สคริปต์ GDScript', '.uid': 'รหัสอ้างอิงทรัพยากร Godot',
             '.import': 'การตั้งค่านำเข้าทรัพยากร Godot', '.png': 'ภาพ PNG',
             '.svg': 'ภาพเวกเตอร์ SVG', '.ttf': 'ไฟล์ฟอนต์', '.json': 'ข้อมูล JSON',
             '.csv': 'ข้อมูลตาราง CSV', '.tscn': 'ฉาก Godot', '.tres': 'ทรัพยากร Godot',
             '.py': 'เครื่องมือ Python', '.sh': 'สคริปต์ Shell', '.yml': 'การตั้งค่า workflow',
             '.yaml': 'การตั้งค่า YAML', '.txt': 'ข้อความ/ตัวอย่างอ้างอิง', '.cfg': 'การตั้งค่า Godot',
             '.godot': 'การตั้งค่าโปรเจกต์ Godot', '.gdshader': 'Shader Godot'}
    kind = kinds.get(suffix, 'ไฟล์ตั้งค่า/ทรัพยากร')
    if path.startswith('docs/examples/'):
        kind = 'ตัวอย่างนำเข้า ไม่ใช่ runtime · ' + kind
    elif path.startswith('docs/reports/'):
        kind = 'หลักฐานย้อนหลัง · ' + kind
    elif path.startswith('tests/'):
        kind = 'การทดสอบ · ' + kind
    elif path.startswith('docs/images/'):
        kind = 'ภาพประกอบเอกสาร · ' + kind
    return kind + ' · ' + file.name


def render():
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    groups = defaultdict(list)
    for path in sorted(filter(None, paths)):
        groups[str(Path(path).parent)].append(path)
    lines = [START, '## สารบัญทุกไฟล์สำหรับ Agent', '',
             'ลิงก์ทุกไฟล์อยู่ในหน้าแรกนี้โดยตรง แต่ละรายการมีคำอธิบายย่อและ **Raw** สำหรับเปิดเนื้อหาโดยไม่ผ่านหน้าแสดงโค้ด GitHub ลิงก์ Raw อ้างอิง `main` หลังรวมการเปลี่ยนแปลงแล้ว ไฟล์ภาพและฟอนต์เป็นไบนารี ไม่ใช่ข้อความเอกสาร', '',
             'เริ่มอ่าน `AGENTS.md` → `docs/STATUS.md` → `docs/development/README.md` แล้วเลือกไฟล์ตามงาน เอกสาร `design/` เป็นแผน/ข้อเสนอ ส่วน `history/` และ `reports/` เป็นหลักฐานย้อนหลัง; ตัวอย่างนำเข้าไม่ใช่คำสั่งที่ติดตั้งใช้งาน', '',
             'สารบัญช่วย Agent ที่เปิดลิงก์ต่อได้ หากระบบจำกัดให้อ่านเฉพาะหน้าแรกจริง ๆ ต้องให้ระบบเปิดสิทธิ์อ่าน URL ปลายทางหรือแนบเนื้อหาเอกสารเพิ่มเติม ลิงก์ไม่เปลี่ยนสิทธิ์การเข้าถึง', '',
             f'รวม **{sum(map(len, groups.values()))} ไฟล์** ที่ Git ติดตาม (รวมไฟล์ซ่อนและไฟล์ประกอบ Godot ไม่รวม `.git/` และไฟล์ที่ยังไม่ติดตาม) อัปเดตด้วย `python3 scripts/update_file_index.py`; ตรวจด้วย `python3 scripts/update_file_index.py --check` หลัง `git add` ไฟล์ใหม่', '']
    for group, files in sorted(groups.items()):
        lines += [f'### `{group}/`' if group != '.' else '### ไฟล์รากโปรเจกต์', '', '| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |', '|---|---|---|']
        for path in files:
            url = quote(path, safe='/')
            lines.append(f'| [{path}]({url}) | {describe(path)} | [Raw]({RAW}{url}) |')
        lines.append('')
    return '\n'.join(lines) + END


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    readme = ROOT / 'README.md'
    text = readme.read_text(encoding='utf-8')
    index = render()
    if START in text:
        before, rest = text.split(START, 1)
        _, after = rest.split(END, 1)
        updated = before + index + after
    else:
        updated = text.rstrip() + '\n\n' + index + '\n'
    if args.check:
        if updated != text:
            parser.exit(1, 'File index is stale; run python3 scripts/update_file_index.py\n')
        print('File index is current.')
    else:
        readme.write_text(updated, encoding='utf-8')
        print('Updated README.md file index.')


if __name__ == '__main__':
    main()
