# 15 ดัชนีตัวอย่างเทคนิค

เอกสารนี้เป็นดัชนีที่จัดทำจากไฟล์แนบ ไม่ใช่เนื้อหาสเปก `15tech` ต้นฉบับ ซึ่งไม่ได้แนบมาทั้งฉบับ ตัวอย่างคงเนื้อหาเดิมและยังไม่ได้ทดสอบกับเกมจริง

## วิธีใช้

ไฟล์ใน `docs/examples/` ใช้อ่านประกอบสเปกเท่านั้น ไฟล์ GDScript ใช้ท้ายชื่อ `.gd.txt` และ shader ใช้ `.gdshader.txt` เพื่อระบุว่าเป็นตัวอย่างซึ่งอาจมีเพียงบางเมธอด ไฟล์ตั้งค่าและ workflow ยังไม่ได้ติดตั้งลงตำแหน่งที่เปิดใช้งาน

สคริปต์ `install-godot.sh` รวมคำสั่งสำหรับหลายระบบปฏิบัติการไว้ในไฟล์เดียว จึงต้องเลือกและตรวจคำสั่งที่ตรงกับระบบก่อนใช้งาน ส่วน `test.sh` และ `run-bots.sh` ต้องมีโปรเจกต์และตัวรันจริงก่อน

## รายการตัวอย่าง

### config

- [project.godot.txt](../examples/config/project.godot.txt) — ต้นฉบับ `_docs_specs_15tech.md_.txt`
- [gitignore.txt](../examples/config/gitignore.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (1).txt`
- [editorconfig.txt](../examples/config/editorconfig.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (2).txt`

### structure

- [scene-tree.txt](../examples/structure/scene-tree.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (3).txt`
- [tile-view.txt](../examples/structure/tile-view.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (13).txt`

### core

- [duplicate-state.gd.txt](../examples/core/duplicate-state.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (5).txt`
- [enum-conversion.gd.txt](../examples/core/enum-conversion.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (6).txt`
- [atomic-save.gd.txt](../examples/core/atomic-save.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (7).txt`
- [mods.gd.txt](../examples/core/mods.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (8).txt`
- [neighbor-cache.gd.txt](../examples/core/neighbor-cache.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (9).txt`
- [water-sim.gd.txt](../examples/core/water-sim.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (10).txt`
- [command-rules.gd.txt](../examples/core/command-rules.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (12).txt`

### view

- [mesh-lib.gd.txt](../examples/view/mesh-lib.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (14).txt`
- [picking.gd.txt](../examples/view/picking.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (16).txt`
- [camera-rig.gd.txt](../examples/view/camera-rig.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (17).txt`
- [water-anim.gd.txt](../examples/view/water-anim.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (18).txt`

### shaders

- [water.gdshader.txt](../examples/shaders/water.gdshader.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (15).txt`

### ui

- [phase-ui.gd.txt](../examples/ui/phase-ui.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (4).txt`
- [theme-builder.gd.txt](../examples/ui/theme-builder.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (19).txt`
- [input-map.gd.txt](../examples/ui/input-map.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (20).txt`
- [audio.gd.txt](../examples/ui/audio.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (21).txt`
- [autosave.gd.txt](../examples/ui/autosave.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (22).txt`
- [screenshot.gd.txt](../examples/ui/screenshot.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (25).txt`

### tests

- [test-case.gd.txt](../examples/tests/test-case.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (23).txt`
- [run-tests.gd.txt](../examples/tests/run-tests.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (24).txt`

### tools

- [bench.gd.txt](../examples/tools/bench.gd.txt) — ต้นฉบับ `_docs_specs_15tech.md_ (11).txt`

### scripts

- [install-godot.sh](../examples/scripts/install-godot.sh) — ต้นฉบับ `_docs_specs_15tech.md_.sh`
- [check-gd.sh](../examples/scripts/check-gd.sh) — ต้นฉบับ `_docs_specs_15tech.md_ (1).sh`
- [test.sh](../examples/scripts/test.sh) — ต้นฉบับ `_docs_specs_15tech.md_ (2).sh`
- [run-bots.sh](../examples/scripts/run-bots.sh) — ต้นฉบับ `_docs_specs_15tech.md_ (3).sh`

### ci

- [tests.yaml](../examples/ci/tests.yaml) — ต้นฉบับ `_docs_specs_15tech.md_.yaml`

### claude

- [permissions.json](../examples/claude/permissions.json) — ต้นฉบับ `_docs_specs_15tech.md_.json`
- [hooks.json](../examples/claude/hooks.json) — ต้นฉบับ `_docs_specs_15tech.md_ (1).json`

### data

- [replay.json](../examples/data/replay.json) — ต้นฉบับ `_docs_specs_15tech.md_ (2).json`
- [balance.json](../examples/data/balance.json) — ต้นฉบับ `_Claude_Code_.json`

## ข้อจำกัดที่พบ

- ปัจจุบันมีโปรเจกต์และคลาสจริงใน root สำหรับต้นแบบ M0–M2 ดู [PROGRESS](../PROGRESS.md); ตัวอย่างในหน้านี้ยังเป็นเอกสารนำเข้าเดิม
- ไม่มีสเปก `03_hex_map.md` สำหรับตรวจอัลกอริทึมแผนที่
- ตัวอย่าง `duplicate-state.gd.txt` มี placeholder ให้คัดลอก scalar fields เพิ่ม
- หมายเลขเวอร์ชันในตัวอย่างต้องตรวจสอบก่อนใช้งาน ไม่ได้ยืนยันว่า Godot เวอร์ชันดังกล่าวดาวน์โหลดได้
- ตัวอย่าง permissions และ hooks ไม่ได้ให้สิทธิ์หรือคำสั่งแก่ session นี้
