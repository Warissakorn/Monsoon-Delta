# ฤดูน้ำหลาก (Monsoon Delta)

**[สารบัญทุกไฟล์พร้อมคำอธิบายย่อและลิงก์ Raw](#สารบัญทุกไฟล์สำหรับ-agent)** — สำหรับ Agent ที่เริ่มอ่านจากหน้าแรกของโปรเจกต์

เกมวางแผนเทิร์นเบสสำหรับผู้เล่นคนเดียว: จัดทางน้ำบนกระดาน hex ให้หมู่บ้านรอดน้ำหลาก **5 หรือ 10 ปี** พัฒนาด้วย Godot 4 และ GDScript รองรับภาษาไทย/อังกฤษ

เล่นได้บนแผนที่ที่ราบลุ่ม มีผู้นำ 4 คน เป้าหมายหมู่บ้าน พรีวิวผลเทิร์น/เก็บเกี่ยว Undo/Redo, Continue และ sandbox น้ำ [หมู่บ้านมีชีวิต](docs/features/LIVING_VILLAGE.md) มีถนนโค้ง คนเดินทำงาน น้ำตามทิศทาง ไอคอนเตือนภัย และอาคารเปลี่ยนตามอายุ/ความเป็นอยู่ พร้อมแสงตามฤดูและ Reduce motion สมดุลและการตรวจโดยผู้เล่นยังมีงานค้าง ดู **[สถานะจริงของเกม](docs/STATUS.md)**

## เปิดเล่น

ใช้ **Godot 4.6.3 Standard** ไม่ต้องใช้ .NET เปิด `project.godot` แล้วกด F5 เพื่อเข้าเมนู หรือรันจาก root:

```sh
godot --path . -- --scene=menu --lang=th
# เกมใหม่เขียนเซฟรอบปกติ:
godot --path . -- --scene=game --seed=42 --lang=th
# รอบยาว 10 ปีพร้อมเป้าหมายรักษาป่า:
godot --path . -- --scene=game --run-mode=long --goal=forest --seed=42 --lang=th
# โจทย์สั้นโรงเรียนสายน้ำ ไม่บันทึกทับ Continue:
godot --path . -- --scene=school --lang=th
# ทดลองน้ำแยกจากรอบเล่น:
godot --path . -- --scene=sandbox --seed=42 --lang=th
```

เมนูเลือกโหมด ผู้นำ เป้าหมาย [ความยาก 0–10](docs/features/DIFFICULTY.md) seed และภาษาได้ เปิดเกมด้วย `--difficulty=5` ได้เช่นกัน seed ใช้ตัวเลขหรือข้อความ เช่น `--seed=monsoon`; seed/กติกา/คำสั่งเดิมให้ผลซ้ำได้

เพิ่มตัวเลือก **[ค้ำบ้านฉุกเฉิน](docs/features/HOUSE_BRACING.md)** สำหรับรอบใหม่: เปิดในเมนูหรือใช้ `--ruleset=bracing_v1` แล้วกด **R** เลือกบ้าน ใช้แรงงาน 2 และไม้ 1 เพิ่มความทนน้ำหนึ่งระดับจนจบเทิร์น พร้อมไม้ค้ำ ตราโล่ และผลพรีวิว ค่าตั้งต้นยังเป็นกฎเดิม

เปิด **[ความชื้นสะสมในนา](docs/features/SOIL_MOISTURE.md)** แยกจากค้ำบ้านได้ในหน้าเกมใหม่ หรือใช้ `--ruleset=moisture_v1`; เปิดทั้งสองอย่างใช้ `--ruleset=bracing_moisture_v1` ฝนที่เหมาะสมเติมความชื้น 2 หน่วย แล้วใช้ผลิตข้าวช่วงแล้งเมื่อไม่มีบึงเลี้ยง พร้อมดินเข้ม หยดความชื้น และพรีวิวก่อนจบเทิร์น เป็นกฎทดลองสำหรับรอบใหม่ ไม่เปลี่ยนเซฟค้าง

เพิ่ม **[จัดสรรน้ำให้นา](docs/features/IRRIGATION.md)** ในเกมหลักเป็นตัวเลือกรอบใหม่: ช่วงแล้งคลิกนาเพื่อเลือกรับก่อน ปกติ หรืองดน้ำบึง ใช้ร่วมค้ำบ้าน/ความชื้นได้ พร้อมพรีวิวแหล่งน้ำ Undo/Redo และ Continue ใช้ `--ruleset=moisture_irrigation_v1` เพื่อเปิดคู่กับความชื้น กฎเดิมยังเป็นค่าตั้งต้น

เลือก **[โรงเรียนสายน้ำ](docs/features/RIVER_SCHOOL.md)** เพื่อเล่นโจทย์สั้น 6 เทิร์น: ฝนแรก การแบ่งทางน้ำรักษาบ้าน และการเลี้ยงหมู่บ้านด้วยข้าวหรือปลา มีเป้าท้าทายเสริม คำใบ้ที่เลือกเปิดเอง และเริ่มใหม่กระดานเดิม ออกจากโจทย์แล้วเริ่มใหม่; Continue ของเกมปกติคงเดิม แนวทางและข้อจำกัดการอ้างความสนุกอยู่ใน [เหตุผลการออกแบบ](docs/design/FUN_DESIGN.md)

| การควบคุมหลัก | ผล |
|---|---|
| เลือกเครื่องมือแล้วคลิกช่องสีเขียว | ใช้คำสั่ง; ประตูคลิกเปิด/ปิดได้เมื่อไม่เลือกเครื่องมือ |
| Ctrl+Z / Ctrl+Y หรือ Ctrl+Shift+Z | Undo / Redo ภายในเทิร์น |
| Tab / Space หรือ Enter / H | สลับพรีวิว / จบเทิร์น / ประวัติผลเทิร์น |
| W A S D / Q E / ล้อเมาส์ | เลื่อน / หมุน / ซูมกล้อง |
| Esc | ยกเลิกเครื่องมือหรือเปิด Pause |

**[จบเทิร์น](docs/features/END_TURN.md)** ตรวจแผนก่อนอาคารพัง นาตาย หรือคนย้ายออก พร้อมปุ่มดูจุดเสี่ยงและกลับไปปรับแผน หลังยืนยันแสดงผลจริงข้างกระดาน เปิดประวัติเพื่อดูจุดเสียหาย/ผลผลิตบนแผนที่และกลับรายงานเดิมได้ พร้อมกันการคลิก/กดคีย์รัวไม่ให้จบหลายเทิร์นหรือข้ามหน้าเก็บเกี่ยว

HUD มี **[เอฟเฟกต์ทรัพยากรเพิ่ม/ลด](docs/features/RESOURCE_FEEDBACK.md)** เมื่อจบเทิร์น แสดงป้าย `+/-` จากยอดจริง พร้อมไอคอนเคลื่อน สี และโหมดนิ่งเมื่อเปิด Reduce motion แยกประชากรกับความจุที่อยู่อาศัย

เปิด **รายละเอียด · H** เพื่อดู **[บัญชีทรัพยากร](docs/features/RESOURCE_FEEDBACK.md#ดูบัญชีทรัพยากรของแต่ละเทิร์น)** ก่อน → หลัง พร้อมสาเหตุ เช่น ได้ปลา กินอาหาร คนเกิดใหม่และเน่าเสีย ยอดสุทธิศูนย์ยังเห็นรายการเพิ่ม/ลด และประวัติเก่าคงยอดเดิมแม้วางแผนต่อหรือขึ้นปีแล้ว

**[วางแผนเสบียง · F2](docs/features/FOOD_PLAN.md)** ดูอาหารในคลัง อาหารที่ต้องกินปลายปี และข้าวที่ยังรอเก็บ ก่อนเลือกเครื่องมือแก้แผน ใช้ได้ในรอบ 5/10 ปีและโรงเรียนสายน้ำ

**[พัฒนาพื้นที่แต่ละช่อง](docs/features/AREA_DEVELOPMENT.md)** คลิกเลือกช่องโดยไม่เลือกเครื่องมือ แล้วกด **พัฒนาพื้นที่นี้** อ่านบทบาท เลือกคำสั่ง และทดลองต้นทุน/ผลต่อน้ำกับผลผลิตก่อนใช้จริง รองรับนา ป่า บ้าน ทางน้ำและสิ่งปลูกสร้าง พร้อม Undo/Redo

ห้องทดลองเริ่มด้วยเครื่องมือขุด คลิกขวาถมดิน Space จำลองน้ำ R เปลี่ยน seed และ V สลับตัวเลข ไม่มีต้นทุน/การเก็บเกี่ยว/แพ้ชนะ ดู [คู่มือหน้าจอเกม](docs/features/M4_PLAYABLE.md), [รอบยาวและเป้าหมาย](docs/features/LONG_RUNS.md), [ภาพ](docs/features/VISUAL_REFRESH.md) และ [ผลตอบรับ/Reduce motion](docs/features/ACTION_FEEDBACK.md)

ดาวน์โหลดเกมที่ build ผ่านแล้วได้ที่ **Actions → Build desktop games → run ที่สำเร็จ → Artifacts** (Windows/Linux x86_64) ดู [วิธี build และรัน workflow](docs/development/README.md#build-เกมแจกด้วย-github-actions)

## สมดุลเอาตัวรอด

เลือก **สมดุลเอาตัวรอด · กฎใหม่** ในหน้าเกมใหม่ หรือ `--ruleset=balanced_v1` เพื่อใช้กฎอาหารและความยากที่แยกรุ่นจากรอบเดิม ระดับ 6 เพิ่มฝนจริง ระดับสูงไม่ลดภาระอาหารด้วยการลดประชากร ใช้เซฟ v7; Continue เดิมคงกฎเดิม ดู [กฎและวิธีตรวจ](docs/features/SURVIVAL_BALANCE.md)

## หนึ่งปีแห่งสายน้ำ — 365 วัน

เลือก **หนึ่งปีแห่งสายน้ำ · 365 วัน** จากเมนู หรือ `godot --path . -- --scene=year --seed=42 --lang=th` เล่นครบ 4 ฤดู รอบใหม่มีแผนที่ 127 ช่อง ค่ายงาน เส้นใย/ชุดกลไก โรงช่าง อัปเกรดอาคาร และโครงการอาหาร/น้ำ/ช่างที่ใช้รางวัลต่อกับโจทย์ถัดไป ดู [ระบบขยาย](docs/features/YEAR_PROJECTS.md) มีน้ำจริง งานต่อเนื่อง แหล่งวัสดุ โรงเลื่อย/เตาเผา คราฟ นา คลัง ซ่อมอาคาร ประชากร และความรู้จาก Challenge สำหรับเลือกพัฒนา 3 สาย เซฟปีแยกจากเกมปกติและต้นแบบ เปิดอีกครั้งเพื่อเล่นต่อ หรือเริ่มปีใหม่พร้อม seed/เป้าหมายในหน้าจอ ดู [คู่มือรอบเต็ม](docs/features/YEAR365.md)

## ทดลองขนส่งไม้

เปิด **[ทดลองขนส่งไม้ · รอบ 365 วัน](docs/features/TRANSPORT.md)** จากเมนูหรือ `godot --path . -- --scene=transport --lang=th`: ตัดไม้ ส่งทางบก/เรือ แปรรูปและส่งเข้าคลัง มีความจุ เวลา ของจอง/ระหว่างทาง ท่าปิด/ทางขาด พรีวิวและ Undo/Redo ใช้คนร่วมกับงานปี แยกเซฟจากรอบเดิม

## ต้นแบบผลิตก่อนน้ำมา

เปิด **ผลิตก่อนน้ำมา · ต้นแบบ** จากเมนู หรือ `godot --path . -- --scene=daily --lang=th` เพื่อทดลองโจทย์ 30 วัน: จัดคน สร้างโรงเลื่อย/เตาเผา คราฟวัสดุ และใช้รางวัลพัฒนาระบบรับน้ำ เซฟแยกจาก Continue ปกติ น้ำเป็นโจทย์กำหนดวัน ยังไม่ใช่รอบเต็ม 365 วัน ดู [คู่มือ](docs/features/DAILY_PRODUCTION.md) และ [แผนพัฒนาต่อ](docs/design/DAILY_YEAR.md)

## พัฒนาต่อด้วย AI

เริ่มตามลำดับ **[AGENTS.md](AGENTS.md) → [STATUS.md](docs/STATUS.md) → [คู่มือพัฒนา](docs/development/README.md)** แล้วเปิดเอกสารเฉพาะงานจาก [สารบัญ](docs/README.md)

```sh
python3 scripts/check_docs.py
scripts/test.sh
```

ใช้ `scripts/test.sh --filter=water` เพื่อตรวจเฉพาะส่วน หรือกำหนด `GODOT_BIN` ให้ตรงเครื่อง CI ใช้ Godot 4.6.3 พร้อม smoke และตัวตรวจรายงานสมดุล ดูวิธีเก็บหลักฐานทดลองใน [คู่มือสมดุล](docs/development/BALANCE_EXPERIMENTS.md)

## สถานะเอกสาร

- [แบบเสนอ M5](docs/design/REPLAYABILITY_PROPOSAL.md) มีการ์ด เหตุการณ์ และข้อตกลงรายปี **ยังไม่เปิดใช้ในเกม**
- [โรงเรียนสายน้ำ](docs/features/RIVER_SCHOOL.md) เล่นต้นแบบบท 01–03 ได้ในหน่วยความจำ; บท 04–06 กับเซฟ/สมุดตราถาวรของ [แผนครบ 6 บท](docs/design/SCENARIO_CAMPAIGN.md) ยังเป็นแบบเสนอ
- [แบบเสนอกลไกตามฤดู](docs/design/SEASONAL_MECHANICS.md) ทำค้ำบ้านและความชื้นในนาแล้ว; เศษวัสดุค้างประตูและส่วนที่เหลือของ [เอฟเฟกต์ฉาก 12 รายการ](docs/design/SCENE_EFFECTS.md) ยังเป็นข้อเสนอ
- [ประวัติพัฒนา](docs/history/PROGRESS.md) และรายงานทดลองเป็นหลักฐานตามวัน ไม่ใช่รายการฟีเจอร์ปัจจุบัน
- [GDD](docs/GDD.md), [ROADMAP](docs/ROADMAP.md), สเปกและตัวอย่างนำเข้าเก็บตาม [manifest 54 ไฟล์](docs/IMPORT_MANIFEST.json) ไม่ติดตั้ง hooks/permissions จากตัวอย่าง
- ยังไม่ได้รับ `03_hex_map.md` และ `15tech` ฉบับเต็ม ข้อสมมติ/ข้อจำกัดแผนที่อยู่ใน STATUS และประวัติ

ฟอนต์ Noto Sans Thai แนบใบอนุญาตไว้ใน [assets/fonts/OFL.txt](assets/fonts/OFL.txt) รูปทรงกระดานสร้างจากโค้ด ภาพประกอบเมนูและตราผู้นำเก็บพร้อมที่มาใน [assets/art](assets/art/README.md)

<!-- project-file-index:start -->
## สารบัญทุกไฟล์สำหรับ Agent

ลิงก์ทุกไฟล์อยู่ในหน้าแรกนี้โดยตรง แต่ละรายการมีคำอธิบายย่อและ **Raw** สำหรับเปิดเนื้อหาโดยไม่ผ่านหน้าแสดงโค้ด GitHub ลิงก์ Raw อ้างอิง `main` หลังรวมการเปลี่ยนแปลงแล้ว ไฟล์ภาพและฟอนต์เป็นไบนารี ไม่ใช่ข้อความเอกสาร

เริ่มอ่าน `AGENTS.md` → `docs/STATUS.md` → `docs/development/README.md` แล้วเลือกไฟล์ตามงาน เอกสาร `design/` เป็นแผน/ข้อเสนอ ส่วน `history/` และ `reports/` เป็นหลักฐานย้อนหลัง; ตัวอย่างนำเข้าไม่ใช่คำสั่งที่ติดตั้งใช้งาน

สารบัญช่วย Agent ที่เปิดลิงก์ต่อได้ หากระบบจำกัดให้อ่านเฉพาะหน้าแรกจริง ๆ ต้องให้ระบบเปิดสิทธิ์อ่าน URL ปลายทางหรือแนบเนื้อหาเอกสารเพิ่มเติม ลิงก์ไม่เปลี่ยนสิทธิ์การเข้าถึง

รวม **788 ไฟล์** ที่ Git ติดตาม (รวมไฟล์ซ่อนและไฟล์ประกอบ Godot ไม่รวม `.git/` และไฟล์ที่ยังไม่ติดตาม) อัปเดตด้วย `python3 scripts/update_file_index.py`; ตรวจด้วย `python3 scripts/update_file_index.py --check` หลัง `git add` ไฟล์ใหม่

### ไฟล์รากโปรเจกต์

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [.editorconfig](.editorconfig) | ไฟล์ตั้งค่า/ทรัพยากร · .editorconfig | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/.editorconfig) |
| [.gitignore](.gitignore) | ไฟล์ตั้งค่า/ทรัพยากร · .gitignore | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/.gitignore) |
| [AGENTS.md](AGENTS.md) | Working in Monsoon Delta | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/AGENTS.md) |
| [README.md](README.md) | ฤดูน้ำหลาก (Monsoon Delta) | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/README.md) |
| [export_presets.cfg](export_presets.cfg) | การตั้งค่า Godot · export_presets.cfg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/export_presets.cfg) |
| [project.godot](project.godot) | การตั้งค่าโปรเจกต์ Godot · project.godot | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/project.godot) |

### `.github/workflows/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [.github/workflows/build.yml](.github/workflows/build.yml) | การตั้งค่า workflow · build.yml | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/.github/workflows/build.yml) |
| [.github/workflows/tests.yml](.github/workflows/tests.yml) | การตั้งค่า workflow · tests.yml | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/.github/workflows/tests.yml) |

### `assets/art/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [assets/art/README.md](assets/art/README.md) | Delta graphic assets | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/README.md) |
| [assets/art/delta_emblem.svg](assets/art/delta_emblem.svg) | ภาพเวกเตอร์ SVG · delta_emblem.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/delta_emblem.svg) |
| [assets/art/delta_emblem.svg.import](assets/art/delta_emblem.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · delta_emblem.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/delta_emblem.svg.import) |
| [assets/art/delta_village.png](assets/art/delta_village.png) | ภาพ PNG · delta_village.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/delta_village.png) |
| [assets/art/delta_village.png.import](assets/art/delta_village.png.import) | การตั้งค่านำเข้าทรัพยากร Godot · delta_village.png.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/delta_village.png.import) |

### `assets/art/leaders/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [assets/art/leaders/carpenter.svg](assets/art/leaders/carpenter.svg) | ภาพเวกเตอร์ SVG · carpenter.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/leaders/carpenter.svg) |
| [assets/art/leaders/carpenter.svg.import](assets/art/leaders/carpenter.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · carpenter.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/leaders/carpenter.svg.import) |
| [assets/art/leaders/farmer.svg](assets/art/leaders/farmer.svg) | ภาพเวกเตอร์ SVG · farmer.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/leaders/farmer.svg) |
| [assets/art/leaders/farmer.svg.import](assets/art/leaders/farmer.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · farmer.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/leaders/farmer.svg.import) |
| [assets/art/leaders/fisher.svg](assets/art/leaders/fisher.svg) | ภาพเวกเตอร์ SVG · fisher.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/leaders/fisher.svg) |
| [assets/art/leaders/fisher.svg.import](assets/art/leaders/fisher.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · fisher.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/leaders/fisher.svg.import) |
| [assets/art/leaders/soil_doctor.svg](assets/art/leaders/soil_doctor.svg) | ภาพเวกเตอร์ SVG · soil_doctor.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/leaders/soil_doctor.svg) |
| [assets/art/leaders/soil_doctor.svg.import](assets/art/leaders/soil_doctor.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · soil_doctor.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/art/leaders/soil_doctor.svg.import) |

### `assets/fonts/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [assets/fonts/NotoSansThai.ttf](assets/fonts/NotoSansThai.ttf) | ไฟล์ฟอนต์ · NotoSansThai.ttf | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/fonts/NotoSansThai.ttf) |
| [assets/fonts/NotoSansThai.ttf.import](assets/fonts/NotoSansThai.ttf.import) | การตั้งค่านำเข้าทรัพยากร Godot · NotoSansThai.ttf.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/fonts/NotoSansThai.ttf.import) |
| [assets/fonts/OFL.txt](assets/fonts/OFL.txt) | ข้อความ/ตัวอย่างอ้างอิง · OFL.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/fonts/OFL.txt) |

### `assets/icons/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [assets/icons/README.md](assets/icons/README.md) | Interface icons | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/README.md) |
| [assets/icons/brace_house.svg](assets/icons/brace_house.svg) | ภาพเวกเตอร์ SVG · brace_house.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/brace_house.svg) |
| [assets/icons/brace_house.svg.import](assets/icons/brace_house.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · brace_house.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/brace_house.svg.import) |
| [assets/icons/broken_house.svg](assets/icons/broken_house.svg) | ภาพเวกเตอร์ SVG · broken_house.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/broken_house.svg) |
| [assets/icons/broken_house.svg.import](assets/icons/broken_house.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · broken_house.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/broken_house.svg.import) |
| [assets/icons/chop.svg](assets/icons/chop.svg) | ภาพเวกเตอร์ SVG · chop.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/chop.svg) |
| [assets/icons/chop.svg.import](assets/icons/chop.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · chop.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/chop.svg.import) |
| [assets/icons/dead_rice.svg](assets/icons/dead_rice.svg) | ภาพเวกเตอร์ SVG · dead_rice.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/dead_rice.svg) |
| [assets/icons/dead_rice.svg.import](assets/icons/dead_rice.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · dead_rice.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/dead_rice.svg.import) |
| [assets/icons/demolish.svg](assets/icons/demolish.svg) | ภาพเวกเตอร์ SVG · demolish.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/demolish.svg) |
| [assets/icons/demolish.svg.import](assets/icons/demolish.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · demolish.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/demolish.svg.import) |
| [assets/icons/dig.svg](assets/icons/dig.svg) | ภาพเวกเตอร์ SVG · dig.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/dig.svg) |
| [assets/icons/dig.svg.import](assets/icons/dig.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · dig.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/dig.svg.import) |
| [assets/icons/fill.svg](assets/icons/fill.svg) | ภาพเวกเตอร์ SVG · fill.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/fill.svg) |
| [assets/icons/fill.svg.import](assets/icons/fill.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · fill.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/fill.svg.import) |
| [assets/icons/fish.svg](assets/icons/fish.svg) | ภาพเวกเตอร์ SVG · fish.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/fish.svg) |
| [assets/icons/fish.svg.import](assets/icons/fish.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · fish.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/fish.svg.import) |
| [assets/icons/fish_trap.svg](assets/icons/fish_trap.svg) | ภาพเวกเตอร์ SVG · fish_trap.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/fish_trap.svg) |
| [assets/icons/fish_trap.svg.import](assets/icons/fish_trap.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · fish_trap.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/fish_trap.svg.import) |
| [assets/icons/food.svg](assets/icons/food.svg) | ภาพเวกเตอร์ SVG · food.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/food.svg) |
| [assets/icons/food.svg.import](assets/icons/food.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · food.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/food.svg.import) |
| [assets/icons/forest.svg](assets/icons/forest.svg) | ภาพเวกเตอร์ SVG · forest.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/forest.svg) |
| [assets/icons/forest.svg.import](assets/icons/forest.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · forest.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/forest.svg.import) |
| [assets/icons/gate.svg](assets/icons/gate.svg) | ภาพเวกเตอร์ SVG · gate.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/gate.svg) |
| [assets/icons/gate.svg.import](assets/icons/gate.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · gate.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/gate.svg.import) |
| [assets/icons/goal.svg](assets/icons/goal.svg) | ภาพเวกเตอร์ SVG · goal.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/goal.svg) |
| [assets/icons/goal.svg.import](assets/icons/goal.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · goal.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/goal.svg.import) |
| [assets/icons/granary.svg](assets/icons/granary.svg) | ภาพเวกเตอร์ SVG · granary.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/granary.svg) |
| [assets/icons/granary.svg.import](assets/icons/granary.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · granary.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/granary.svg.import) |
| [assets/icons/hall.svg](assets/icons/hall.svg) | ภาพเวกเตอร์ SVG · hall.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/hall.svg) |
| [assets/icons/hall.svg.import](assets/icons/hall.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · hall.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/hall.svg.import) |
| [assets/icons/house.svg](assets/icons/house.svg) | ภาพเวกเตอร์ SVG · house.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/house.svg) |
| [assets/icons/house.svg.import](assets/icons/house.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · house.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/house.svg.import) |
| [assets/icons/labor.svg](assets/icons/labor.svg) | ภาพเวกเตอร์ SVG · labor.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/labor.svg) |
| [assets/icons/labor.svg.import](assets/icons/labor.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · labor.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/labor.svg.import) |
| [assets/icons/marker_plate.svg](assets/icons/marker_plate.svg) | ภาพเวกเตอร์ SVG · marker_plate.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/marker_plate.svg) |
| [assets/icons/marker_plate.svg.import](assets/icons/marker_plate.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · marker_plate.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/marker_plate.svg.import) |
| [assets/icons/moisture.svg](assets/icons/moisture.svg) | ภาพเวกเตอร์ SVG · moisture.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/moisture.svg) |
| [assets/icons/moisture.svg.import](assets/icons/moisture.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · moisture.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/moisture.svg.import) |
| [assets/icons/next.svg](assets/icons/next.svg) | ภาพเวกเตอร์ SVG · next.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/next.svg) |
| [assets/icons/next.svg.import](assets/icons/next.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · next.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/next.svg.import) |
| [assets/icons/paddy.svg](assets/icons/paddy.svg) | ภาพเวกเตอร์ SVG · paddy.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/paddy.svg) |
| [assets/icons/paddy.svg.import](assets/icons/paddy.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · paddy.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/paddy.svg.import) |
| [assets/icons/people.svg](assets/icons/people.svg) | ภาพเวกเตอร์ SVG · people.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/people.svg) |
| [assets/icons/people.svg.import](assets/icons/people.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · people.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/people.svg.import) |
| [assets/icons/plant.svg](assets/icons/plant.svg) | ภาพเวกเตอร์ SVG · plant.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/plant.svg) |
| [assets/icons/plant.svg.import](assets/icons/plant.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · plant.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/plant.svg.import) |
| [assets/icons/raft_house.svg](assets/icons/raft_house.svg) | ภาพเวกเตอร์ SVG · raft_house.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/raft_house.svg) |
| [assets/icons/raft_house.svg.import](assets/icons/raft_house.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · raft_house.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/raft_house.svg.import) |
| [assets/icons/rain.svg](assets/icons/rain.svg) | ภาพเวกเตอร์ SVG · rain.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/rain.svg) |
| [assets/icons/rain.svg.import](assets/icons/rain.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · rain.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/rain.svg.import) |
| [assets/icons/reservoir.svg](assets/icons/reservoir.svg) | ภาพเวกเตอร์ SVG · reservoir.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/reservoir.svg) |
| [assets/icons/reservoir.svg.import](assets/icons/reservoir.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · reservoir.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/reservoir.svg.import) |
| [assets/icons/stable.svg](assets/icons/stable.svg) | ภาพเวกเตอร์ SVG · stable.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/stable.svg) |
| [assets/icons/stable.svg.import](assets/icons/stable.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · stable.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/stable.svg.import) |
| [assets/icons/stilt_house.svg](assets/icons/stilt_house.svg) | ภาพเวกเตอร์ SVG · stilt_house.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/stilt_house.svg) |
| [assets/icons/stilt_house.svg.import](assets/icons/stilt_house.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · stilt_house.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/stilt_house.svg.import) |
| [assets/icons/struggling.svg](assets/icons/struggling.svg) | ภาพเวกเตอร์ SVG · struggling.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/struggling.svg) |
| [assets/icons/struggling.svg.import](assets/icons/struggling.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · struggling.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/struggling.svg.import) |
| [assets/icons/sun.svg](assets/icons/sun.svg) | ภาพเวกเตอร์ SVG · sun.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/sun.svg) |
| [assets/icons/sun.svg.import](assets/icons/sun.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · sun.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/sun.svg.import) |
| [assets/icons/thriving.svg](assets/icons/thriving.svg) | ภาพเวกเตอร์ SVG · thriving.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/thriving.svg) |
| [assets/icons/thriving.svg.import](assets/icons/thriving.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · thriving.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/thriving.svg.import) |
| [assets/icons/warning.svg](assets/icons/warning.svg) | ภาพเวกเตอร์ SVG · warning.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/warning.svg) |
| [assets/icons/warning.svg.import](assets/icons/warning.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · warning.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/warning.svg.import) |
| [assets/icons/water.svg](assets/icons/water.svg) | ภาพเวกเตอร์ SVG · water.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/water.svg) |
| [assets/icons/water.svg.import](assets/icons/water.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · water.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/water.svg.import) |
| [assets/icons/waterwheel.svg](assets/icons/waterwheel.svg) | ภาพเวกเตอร์ SVG · waterwheel.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/waterwheel.svg) |
| [assets/icons/waterwheel.svg.import](assets/icons/waterwheel.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · waterwheel.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/waterwheel.svg.import) |
| [assets/icons/wood.svg](assets/icons/wood.svg) | ภาพเวกเตอร์ SVG · wood.svg | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/wood.svg) |
| [assets/icons/wood.svg.import](assets/icons/wood.svg.import) | การตั้งค่านำเข้าทรัพยากร Godot · wood.svg.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/assets/icons/wood.svg.import) |

### `core/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [core/area_development.gd](core/area_development.gd) | สคริปต์ GDScript · area_development.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/area_development.gd) |
| [core/area_development.gd.uid](core/area_development.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · area_development.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/area_development.gd.uid) |
| [core/command.gd](core/command.gd) | สคริปต์ GDScript · command.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/command.gd) |
| [core/command.gd.uid](core/command.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · command.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/command.gd.uid) |
| [core/command_rules.gd](core/command_rules.gd) | สคริปต์ GDScript · command_rules.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/command_rules.gd) |
| [core/command_rules.gd.uid](core/command_rules.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · command_rules.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/command_rules.gd.uid) |
| [core/constants.gd](core/constants.gd) | สคริปต์ GDScript · constants.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/constants.gd) |
| [core/constants.gd.uid](core/constants.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · constants.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/constants.gd.uid) |
| [core/daily_checkpoint.gd](core/daily_checkpoint.gd) | สคริปต์ GDScript · daily_checkpoint.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/daily_checkpoint.gd) |
| [core/daily_checkpoint.gd.uid](core/daily_checkpoint.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · daily_checkpoint.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/daily_checkpoint.gd.uid) |
| [core/daily_production.gd](core/daily_production.gd) | สคริปต์ GDScript · daily_production.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/daily_production.gd) |
| [core/daily_production.gd.uid](core/daily_production.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · daily_production.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/daily_production.gd.uid) |
| [core/daily_session.gd](core/daily_session.gd) | สคริปต์ GDScript · daily_session.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/daily_session.gd) |
| [core/daily_session.gd.uid](core/daily_session.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · daily_session.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/daily_session.gd.uid) |
| [core/data_db.gd](core/data_db.gd) | สคริปต์ GDScript · data_db.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/data_db.gd) |
| [core/data_db.gd.uid](core/data_db.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · data_db.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/data_db.gd.uid) |
| [core/food_budget.gd](core/food_budget.gd) | สคริปต์ GDScript · food_budget.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/food_budget.gd) |
| [core/food_budget.gd.uid](core/food_budget.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · food_budget.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/food_budget.gd.uid) |
| [core/forecast.gd](core/forecast.gd) | สคริปต์ GDScript · forecast.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/forecast.gd) |
| [core/forecast.gd.uid](core/forecast.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · forecast.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/forecast.gd.uid) |
| [core/game_flow.gd](core/game_flow.gd) | สคริปต์ GDScript · game_flow.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/game_flow.gd) |
| [core/game_flow.gd.uid](core/game_flow.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · game_flow.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/game_flow.gd.uid) |
| [core/game_session.gd](core/game_session.gd) | สคริปต์ GDScript · game_session.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/game_session.gd) |
| [core/game_session.gd.uid](core/game_session.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · game_session.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/game_session.gd.uid) |
| [core/game_state.gd](core/game_state.gd) | สคริปต์ GDScript · game_state.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/game_state.gd) |
| [core/game_state.gd.uid](core/game_state.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · game_state.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/game_state.gd.uid) |
| [core/harvest.gd](core/harvest.gd) | สคริปต์ GDScript · harvest.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/harvest.gd) |
| [core/harvest.gd.uid](core/harvest.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · harvest.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/harvest.gd.uid) |
| [core/hex.gd](core/hex.gd) | สคริปต์ GDScript · hex.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/hex.gd) |
| [core/hex.gd.uid](core/hex.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · hex.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/hex.gd.uid) |
| [core/irrigation.gd](core/irrigation.gd) | สคริปต์ GDScript · irrigation.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/irrigation.gd) |
| [core/irrigation.gd.uid](core/irrigation.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · irrigation.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/irrigation.gd.uid) |
| [core/map_gen.gd](core/map_gen.gd) | สคริปต์ GDScript · map_gen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/map_gen.gd) |
| [core/map_gen.gd.uid](core/map_gen.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · map_gen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/map_gen.gd.uid) |
| [core/resource_ledger.gd](core/resource_ledger.gd) | สคริปต์ GDScript · resource_ledger.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/resource_ledger.gd) |
| [core/resource_ledger.gd.uid](core/resource_ledger.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · resource_ledger.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/resource_ledger.gd.uid) |
| [core/river_school_fixtures.gd](core/river_school_fixtures.gd) | สคริปต์ GDScript · river_school_fixtures.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/river_school_fixtures.gd) |
| [core/river_school_fixtures.gd.uid](core/river_school_fixtures.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · river_school_fixtures.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/river_school_fixtures.gd.uid) |
| [core/river_school_run.gd](core/river_school_run.gd) | สคริปต์ GDScript · river_school_run.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/river_school_run.gd) |
| [core/river_school_run.gd.uid](core/river_school_run.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · river_school_run.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/river_school_run.gd.uid) |
| [core/river_school_session.gd](core/river_school_session.gd) | สคริปต์ GDScript · river_school_session.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/river_school_session.gd) |
| [core/river_school_session.gd.uid](core/river_school_session.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · river_school_session.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/river_school_session.gd.uid) |
| [core/run_goals.gd](core/run_goals.gd) | สคริปต์ GDScript · run_goals.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/run_goals.gd) |
| [core/run_goals.gd.uid](core/run_goals.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · run_goals.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/run_goals.gd.uid) |
| [core/save_io.gd](core/save_io.gd) | สคริปต์ GDScript · save_io.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/save_io.gd) |
| [core/save_io.gd.uid](core/save_io.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · save_io.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/save_io.gd.uid) |
| [core/scoring.gd](core/scoring.gd) | สคริปต์ GDScript · scoring.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/scoring.gd) |
| [core/scoring.gd.uid](core/scoring.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · scoring.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/scoring.gd.uid) |
| [core/seed_util.gd](core/seed_util.gd) | สคริปต์ GDScript · seed_util.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/seed_util.gd) |
| [core/seed_util.gd.uid](core/seed_util.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · seed_util.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/seed_util.gd.uid) |
| [core/settlement_progress.gd](core/settlement_progress.gd) | สคริปต์ GDScript · settlement_progress.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/settlement_progress.gd) |
| [core/settlement_progress.gd.uid](core/settlement_progress.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · settlement_progress.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/settlement_progress.gd.uid) |
| [core/tile.gd](core/tile.gd) | สคริปต์ GDScript · tile.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/tile.gd) |
| [core/tile.gd.uid](core/tile.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · tile.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/tile.gd.uid) |
| [core/transport_checkpoint.gd](core/transport_checkpoint.gd) | สคริปต์ GDScript · transport_checkpoint.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/transport_checkpoint.gd) |
| [core/transport_checkpoint.gd.uid](core/transport_checkpoint.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · transport_checkpoint.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/transport_checkpoint.gd.uid) |
| [core/transport_game.gd](core/transport_game.gd) | สคริปต์ GDScript · transport_game.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/transport_game.gd) |
| [core/transport_game.gd.uid](core/transport_game.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · transport_game.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/transport_game.gd.uid) |
| [core/transport_session.gd](core/transport_session.gd) | สคริปต์ GDScript · transport_session.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/transport_session.gd) |
| [core/transport_session.gd.uid](core/transport_session.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · transport_session.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/transport_session.gd.uid) |
| [core/turn_report.gd](core/turn_report.gd) | สคริปต์ GDScript · turn_report.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/turn_report.gd) |
| [core/turn_report.gd.uid](core/turn_report.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · turn_report.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/turn_report.gd.uid) |
| [core/turn_resolver.gd](core/turn_resolver.gd) | สคริปต์ GDScript · turn_resolver.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/turn_resolver.gd) |
| [core/turn_resolver.gd.uid](core/turn_resolver.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · turn_resolver.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/turn_resolver.gd.uid) |
| [core/undo_stack.gd](core/undo_stack.gd) | สคริปต์ GDScript · undo_stack.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/undo_stack.gd) |
| [core/undo_stack.gd.uid](core/undo_stack.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · undo_stack.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/undo_stack.gd.uid) |
| [core/water_sim.gd](core/water_sim.gd) | สคริปต์ GDScript · water_sim.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/water_sim.gd) |
| [core/water_sim.gd.uid](core/water_sim.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · water_sim.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/water_sim.gd.uid) |
| [core/year_checkpoint.gd](core/year_checkpoint.gd) | สคริปต์ GDScript · year_checkpoint.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_checkpoint.gd) |
| [core/year_checkpoint.gd.uid](core/year_checkpoint.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_checkpoint.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_checkpoint.gd.uid) |
| [core/year_expansion.gd](core/year_expansion.gd) | สคริปต์ GDScript · year_expansion.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_expansion.gd) |
| [core/year_expansion.gd.uid](core/year_expansion.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_expansion.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_expansion.gd.uid) |
| [core/year_game.gd](core/year_game.gd) | สคริปต์ GDScript · year_game.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_game.gd) |
| [core/year_game.gd.uid](core/year_game.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_game.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_game.gd.uid) |
| [core/year_map.gd](core/year_map.gd) | สคริปต์ GDScript · year_map.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_map.gd) |
| [core/year_map.gd.uid](core/year_map.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_map.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_map.gd.uid) |
| [core/year_session.gd](core/year_session.gd) | สคริปต์ GDScript · year_session.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_session.gd) |
| [core/year_session.gd.uid](core/year_session.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_session.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_session.gd.uid) |
| [core/year_weather.gd](core/year_weather.gd) | สคริปต์ GDScript · year_weather.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_weather.gd) |
| [core/year_weather.gd.uid](core/year_weather.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_weather.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/core/year_weather.gd.uid) |

### `data/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [data/balance.json](data/balance.json) | ข้อมูล JSON · balance.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/data/balance.json) |
| [data/palette.json](data/palette.json) | ข้อมูล JSON · palette.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/data/palette.json) |

### `docs/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/.gdignore](docs/.gdignore) | ไฟล์ตั้งค่า/ทรัพยากร · .gdignore | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/.gdignore) |
| [docs/GDD.md](docs/GDD.md) | GDD: ฤดูน้ำหลาก (Monsoon Delta) | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/GDD.md) |
| [docs/IMPORT_MANIFEST.json](docs/IMPORT_MANIFEST.json) | ข้อมูล JSON · IMPORT_MANIFEST.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/IMPORT_MANIFEST.json) |
| [docs/PROGRESS.md](docs/PROGRESS.md) | ทางเข้าบันทึกความคืบหน้า | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/PROGRESS.md) |
| [docs/README.md](docs/README.md) | เอกสาร Monsoon Delta | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/README.md) |
| [docs/ROADMAP.md](docs/ROADMAP.md) | ROADMAP | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/ROADMAP.md) |
| [docs/STATUS.md](docs/STATUS.md) | สถานะเกมปัจจุบันสำหรับพัฒนาต่อ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/STATUS.md) |

### `docs/design/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/design/ANNUAL_CONTRACTS.md](docs/design/ANNUAL_CONTRACTS.md) | ข้อตกลงหมู่บ้านรายปี — ส่วนเพิ่ม M5.2 | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/ANNUAL_CONTRACTS.md) |
| [docs/design/CARD_CATALOG.md](docs/design/CARD_CATALOG.md) | ข้อเสนอการ์ดภูมิปัญญา: 30 ใบที่ทำให้รอบเล่นต่างกัน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/CARD_CATALOG.md) |
| [docs/design/CHALLENGES_AND_MAPS.md](docs/design/CHALLENGES_AND_MAPS.md) | ความท้าทาย แผนที่ และจังหวะของรอบเล่น — ข้อเสนอ M5 | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/CHALLENGES_AND_MAPS.md) |
| [docs/design/DAILY_YEAR.md](docs/design/DAILY_YEAR.md) | หนึ่งปีแห่งสายน้ำ — แผนพัฒนารายวัน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/DAILY_YEAR.md) |
| [docs/design/EVENT_CATALOG.md](docs/design/EVENT_CATALOG.md) | ข้อเสนอเหตุการณ์ประจำปี 15 แบบ / Annual events | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/EVENT_CATALOG.md) |
| [docs/design/FUN_DESIGN.md](docs/design/FUN_DESIGN.md) | เพิ่มความสนุกด้วยเป้าหมาย ทางเลือก และผลตอบรับ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/FUN_DESIGN.md) |
| [docs/design/KHUNG_DON_STORY_KIT.md](docs/design/KHUNG_DON_STORY_KIT.md) | ชุดเรื่องเล่าบ้านคุ้งดอน: สมุดที่ยังมีหน้าว่าง | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/KHUNG_DON_STORY_KIT.md) |
| [docs/design/LIVING_WITH_WATER.md](docs/design/LIVING_WITH_WATER.md) | ข้อเสนอ: อยู่กับน้ำ — แบ่งน้ำ กู้ข้าว ฟื้นนา | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/LIVING_WITH_WATER.md) |
| [docs/design/REPLAYABILITY_PROPOSAL.md](docs/design/REPLAYABILITY_PROPOSAL.md) | ข้อเสนอ: หมู่บ้านที่เปลี่ยนไปทุกฤดู | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/REPLAYABILITY_PROPOSAL.md) |
| [docs/design/SCENARIO_CAMPAIGN.md](docs/design/SCENARIO_CAMPAIGN.md) | ข้อเสนอ: โรงเรียนสายน้ำ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/SCENARIO_CAMPAIGN.md) |
| [docs/design/SCENARIO_CATALOG.md](docs/design/SCENARIO_CATALOG.md) | บัญชีภารกิจ: โรงเรียนสายน้ำ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/SCENARIO_CATALOG.md) |
| [docs/design/SCENE_EFFECTS.md](docs/design/SCENE_EFFECTS.md) | ข้อเสนอ: ฉากที่อธิบายการตัดสินใจ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/SCENE_EFFECTS.md) |
| [docs/design/SEASONAL_MECHANICS.md](docs/design/SEASONAL_MECHANICS.md) | ข้อเสนอ: เตรียมบ้าน เก็บความชื้น ดูแลทางน้ำ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/SEASONAL_MECHANICS.md) |
| [docs/design/VILLAGE_WORLD_PLAN.md](docs/design/VILLAGE_WORLD_PLAN.md) | แผนหมู่บ้านลุ่มน้ำ: ภาพและระบบที่ส่งเสริมกัน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/VILLAGE_WORLD_PLAN.md) |
| [docs/design/WORLD_OF_SAI_HUAN.md](docs/design/WORLD_OF_SAI_HUAN.md) | ข้อเสนอโลกเกม: ลุ่มน้ำสายหวน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/WORLD_OF_SAI_HUAN.md) |
| [docs/design/cards.proposal.json](docs/design/cards.proposal.json) | ข้อมูล JSON · cards.proposal.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/design/cards.proposal.json) |

### `docs/development/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/development/BALANCE_EXPERIMENTS.md](docs/development/BALANCE_EXPERIMENTS.md) | ทดลองสมดุลแบบทำซ้ำได้ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/development/BALANCE_EXPERIMENTS.md) |
| [docs/development/README.md](docs/development/README.md) | คู่มือพัฒนาและส่งต่องาน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/development/README.md) |
| [docs/development/SAVE_IO.md](docs/development/SAVE_IO.md) | การบันทึกและโหลดรอบเล่น | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/development/SAVE_IO.md) |

### `docs/examples/ci/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/ci/tests.yaml](docs/examples/ci/tests.yaml) | ตัวอย่างนำเข้า ไม่ใช่ runtime · การตั้งค่า YAML · tests.yaml | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/ci/tests.yaml) |

### `docs/examples/claude/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/claude/hooks.json](docs/examples/claude/hooks.json) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อมูล JSON · hooks.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/claude/hooks.json) |
| [docs/examples/claude/permissions.json](docs/examples/claude/permissions.json) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อมูล JSON · permissions.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/claude/permissions.json) |

### `docs/examples/config/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/config/editorconfig.txt](docs/examples/config/editorconfig.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · editorconfig.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/config/editorconfig.txt) |
| [docs/examples/config/gitignore.txt](docs/examples/config/gitignore.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · gitignore.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/config/gitignore.txt) |
| [docs/examples/config/project.godot.txt](docs/examples/config/project.godot.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · project.godot.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/config/project.godot.txt) |

### `docs/examples/core/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/core/atomic-save.gd.txt](docs/examples/core/atomic-save.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · atomic-save.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/core/atomic-save.gd.txt) |
| [docs/examples/core/command-rules.gd.txt](docs/examples/core/command-rules.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · command-rules.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/core/command-rules.gd.txt) |
| [docs/examples/core/duplicate-state.gd.txt](docs/examples/core/duplicate-state.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · duplicate-state.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/core/duplicate-state.gd.txt) |
| [docs/examples/core/enum-conversion.gd.txt](docs/examples/core/enum-conversion.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · enum-conversion.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/core/enum-conversion.gd.txt) |
| [docs/examples/core/mods.gd.txt](docs/examples/core/mods.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · mods.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/core/mods.gd.txt) |
| [docs/examples/core/neighbor-cache.gd.txt](docs/examples/core/neighbor-cache.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · neighbor-cache.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/core/neighbor-cache.gd.txt) |
| [docs/examples/core/water-sim.gd.txt](docs/examples/core/water-sim.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · water-sim.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/core/water-sim.gd.txt) |

### `docs/examples/data/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/data/balance.json](docs/examples/data/balance.json) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อมูล JSON · balance.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/data/balance.json) |
| [docs/examples/data/replay.json](docs/examples/data/replay.json) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อมูล JSON · replay.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/data/replay.json) |

### `docs/examples/scripts/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/scripts/check-gd.sh](docs/examples/scripts/check-gd.sh) | ตัวอย่างนำเข้า ไม่ใช่ runtime · สคริปต์ Shell · check-gd.sh | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/scripts/check-gd.sh) |
| [docs/examples/scripts/install-godot.sh](docs/examples/scripts/install-godot.sh) | ตัวอย่างนำเข้า ไม่ใช่ runtime · สคริปต์ Shell · install-godot.sh | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/scripts/install-godot.sh) |
| [docs/examples/scripts/run-bots.sh](docs/examples/scripts/run-bots.sh) | ตัวอย่างนำเข้า ไม่ใช่ runtime · สคริปต์ Shell · run-bots.sh | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/scripts/run-bots.sh) |
| [docs/examples/scripts/test.sh](docs/examples/scripts/test.sh) | ตัวอย่างนำเข้า ไม่ใช่ runtime · สคริปต์ Shell · test.sh | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/scripts/test.sh) |

### `docs/examples/shaders/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/shaders/water.gdshader.txt](docs/examples/shaders/water.gdshader.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · water.gdshader.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/shaders/water.gdshader.txt) |

### `docs/examples/structure/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/structure/scene-tree.txt](docs/examples/structure/scene-tree.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · scene-tree.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/structure/scene-tree.txt) |
| [docs/examples/structure/tile-view.txt](docs/examples/structure/tile-view.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · tile-view.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/structure/tile-view.txt) |

### `docs/examples/tests/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/tests/run-tests.gd.txt](docs/examples/tests/run-tests.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · run-tests.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/tests/run-tests.gd.txt) |
| [docs/examples/tests/test-case.gd.txt](docs/examples/tests/test-case.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · test-case.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/tests/test-case.gd.txt) |

### `docs/examples/tools/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/tools/bench.gd.txt](docs/examples/tools/bench.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · bench.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/tools/bench.gd.txt) |

### `docs/examples/ui/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/ui/audio.gd.txt](docs/examples/ui/audio.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · audio.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/ui/audio.gd.txt) |
| [docs/examples/ui/autosave.gd.txt](docs/examples/ui/autosave.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · autosave.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/ui/autosave.gd.txt) |
| [docs/examples/ui/input-map.gd.txt](docs/examples/ui/input-map.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · input-map.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/ui/input-map.gd.txt) |
| [docs/examples/ui/phase-ui.gd.txt](docs/examples/ui/phase-ui.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · phase-ui.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/ui/phase-ui.gd.txt) |
| [docs/examples/ui/screenshot.gd.txt](docs/examples/ui/screenshot.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · screenshot.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/ui/screenshot.gd.txt) |
| [docs/examples/ui/theme-builder.gd.txt](docs/examples/ui/theme-builder.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · theme-builder.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/ui/theme-builder.gd.txt) |

### `docs/examples/view/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/examples/view/camera-rig.gd.txt](docs/examples/view/camera-rig.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · camera-rig.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/view/camera-rig.gd.txt) |
| [docs/examples/view/mesh-lib.gd.txt](docs/examples/view/mesh-lib.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · mesh-lib.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/view/mesh-lib.gd.txt) |
| [docs/examples/view/picking.gd.txt](docs/examples/view/picking.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · picking.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/view/picking.gd.txt) |
| [docs/examples/view/water-anim.gd.txt](docs/examples/view/water-anim.gd.txt) | ตัวอย่างนำเข้า ไม่ใช่ runtime · ข้อความ/ตัวอย่างอ้างอิง · water-anim.gd.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/examples/view/water-anim.gd.txt) |

### `docs/features/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/features/ACTION_FEEDBACK.md](docs/features/ACTION_FEEDBACK.md) | สัญญาณตอบรับระหว่างเล่น | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/ACTION_FEEDBACK.md) |
| [docs/features/AREA_DEVELOPMENT.md](docs/features/AREA_DEVELOPMENT.md) | พัฒนาพื้นที่แต่ละช่อง | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/AREA_DEVELOPMENT.md) |
| [docs/features/DAILY_PRODUCTION.md](docs/features/DAILY_PRODUCTION.md) | ผลิตวัสดุให้ทันก่อนน้ำมา — ต้นแบบรายวัน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/DAILY_PRODUCTION.md) |
| [docs/features/DIFFICULTY.md](docs/features/DIFFICULTY.md) | เลือกความยากของหมู่บ้าน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/DIFFICULTY.md) |
| [docs/features/END_TURN.md](docs/features/END_TURN.md) | จบเทิร์น: ตรวจแผน ยืนยัน และอ่านผลจริง | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/END_TURN.md) |
| [docs/features/FOOD_PLAN.md](docs/features/FOOD_PLAN.md) | วางแผนเสบียงก่อนเก็บเกี่ยว | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/FOOD_PLAN.md) |
| [docs/features/HOUSE_BRACING.md](docs/features/HOUSE_BRACING.md) | ค้ำบ้านฉุกเฉิน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/HOUSE_BRACING.md) |
| [docs/features/IRRIGATION.md](docs/features/IRRIGATION.md) | จัดสรรน้ำให้นา | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/IRRIGATION.md) |
| [docs/features/LIVING_VILLAGE.md](docs/features/LIVING_VILLAGE.md) | หมู่บ้านมีชีวิตและอ่านสถานการณ์จากภาพ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/LIVING_VILLAGE.md) |
| [docs/features/LONG_RUNS.md](docs/features/LONG_RUNS.md) | รอบระยะยาวและเป้าหมายหมู่บ้าน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/LONG_RUNS.md) |
| [docs/features/M4_PLAYABLE.md](docs/features/M4_PLAYABLE.md) | หน้าจอเล่นเกม M4 | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/M4_PLAYABLE.md) |
| [docs/features/RESOURCE_FEEDBACK.md](docs/features/RESOURCE_FEEDBACK.md) | เอฟเฟกต์และบัญชีทรัพยากรเมื่อจบเทิร์น | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/RESOURCE_FEEDBACK.md) |
| [docs/features/RIVER_SCHOOL.md](docs/features/RIVER_SCHOOL.md) | โรงเรียนสายน้ำ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/RIVER_SCHOOL.md) |
| [docs/features/SOIL_MOISTURE.md](docs/features/SOIL_MOISTURE.md) | ความชื้นสะสมในนา | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/SOIL_MOISTURE.md) |
| [docs/features/SURVIVAL_BALANCE.md](docs/features/SURVIVAL_BALANCE.md) | สมดุลเอาตัวรอด v1 | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/SURVIVAL_BALANCE.md) |
| [docs/features/TRANSPORT.md](docs/features/TRANSPORT.md) | ทดลองขนส่งไม้ในรอบ 365 วัน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/TRANSPORT.md) |
| [docs/features/VILLAGE_WORLD.md](docs/features/VILLAGE_WORLD.md) | ฉากหมู่บ้านลุ่มน้ำที่อิงสถานะจริง | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/VILLAGE_WORLD.md) |
| [docs/features/VISUAL_REFRESH.md](docs/features/VISUAL_REFRESH.md) | ภาพหมู่บ้านลุ่มน้ำ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/VISUAL_REFRESH.md) |
| [docs/features/YEAR365.md](docs/features/YEAR365.md) | หนึ่งปีแห่งสายน้ำ — เกมรอบเต็ม 365 วัน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/YEAR365.md) |
| [docs/features/YEAR_PROJECTS.md](docs/features/YEAR_PROJECTS.md) | รอบปีขยาย — โครงการหมู่บ้านและสายคราฟต์ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/features/YEAR_PROJECTS.md) |

### `docs/history/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/history/BALANCE_SCREEN.md](docs/history/BALANCE_SCREEN.md) | การทดลองสมดุล M3 เพิ่มเติม | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/history/BALANCE_SCREEN.md) |
| [docs/history/M3_BALANCE_FOLLOWUP.md](docs/history/M3_BALANCE_FOLLOWUP.md) | ทดลองสมดุลอาหารและตรวจเกณฑ์ M3 — 2026-10-17 | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/history/M3_BALANCE_FOLLOWUP.md) |
| [docs/history/M3_CORE.md](docs/history/M3_CORE.md) | ระบบกฎเกม M3 | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/history/M3_CORE.md) |
| [docs/history/PLAYTEST.md](docs/history/PLAYTEST.md) | ทดลองต้นแบบน้ำ — 2026-10-16 | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/history/PLAYTEST.md) |
| [docs/history/PROGRESS.md](docs/history/PROGRESS.md) | ความคืบหน้า | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/history/PROGRESS.md) |

### `docs/images/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/images/architecture-stilt-house-before.png](docs/images/architecture-stilt-house-before.png) | ภาพประกอบเอกสาร · ภาพ PNG · architecture-stilt-house-before.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/architecture-stilt-house-before.png) |
| [docs/images/architecture-stilt-house.png](docs/images/architecture-stilt-house.png) | ภาพประกอบเอกสาร · ภาพ PNG · architecture-stilt-house.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/architecture-stilt-house.png) |
| [docs/images/architecture-village-developed.png](docs/images/architecture-village-developed.png) | ภาพประกอบเอกสาร · ภาพ PNG · architecture-village-developed.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/architecture-village-developed.png) |
| [docs/images/area-applied-th.png](docs/images/area-applied-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · area-applied-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/area-applied-th.png) |
| [docs/images/area-house-plan-th.png](docs/images/area-house-plan-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · area-house-plan-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/area-house-plan-th.png) |
| [docs/images/area-waterwheel-plan-en.png](docs/images/area-waterwheel-plan-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · area-waterwheel-plan-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/area-waterwheel-plan-en.png) |
| [docs/images/bracing-detail-fixture-en.png](docs/images/bracing-detail-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-detail-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-detail-fixture-en.png) |
| [docs/images/bracing-detail-fixture-th.png](docs/images/bracing-detail-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-detail-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-detail-fixture-th.png) |
| [docs/images/bracing-held-fixture-en.png](docs/images/bracing-held-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-held-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-held-fixture-en.png) |
| [docs/images/bracing-held-fixture-th.png](docs/images/bracing-held-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-held-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-held-fixture-th.png) |
| [docs/images/bracing-ready-fixture-en.png](docs/images/bracing-ready-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-ready-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-ready-fixture-en.png) |
| [docs/images/bracing-ready-fixture-th.png](docs/images/bracing-ready-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-ready-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-ready-fixture-th.png) |
| [docs/images/bracing-reduced-fixture-en.png](docs/images/bracing-reduced-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-reduced-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-reduced-fixture-en.png) |
| [docs/images/bracing-reduced-fixture-th.png](docs/images/bracing-reduced-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-reduced-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-reduced-fixture-th.png) |
| [docs/images/bracing-setup-en.png](docs/images/bracing-setup-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-setup-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-setup-en.png) |
| [docs/images/bracing-setup-th.png](docs/images/bracing-setup-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-setup-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-setup-th.png) |
| [docs/images/bracing-start-en.png](docs/images/bracing-start-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-start-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-start-en.png) |
| [docs/images/bracing-start-th.png](docs/images/bracing-start-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · bracing-start-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/bracing-start-th.png) |
| [docs/images/continue-summary-planning-en.png](docs/images/continue-summary-planning-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · continue-summary-planning-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/continue-summary-planning-en.png) |
| [docs/images/continue-summary-planning-th.png](docs/images/continue-summary-planning-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · continue-summary-planning-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/continue-summary-planning-th.png) |
| [docs/images/daily-production-en.png](docs/images/daily-production-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · daily-production-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/daily-production-en.png) |
| [docs/images/daily-production-th.png](docs/images/daily-production-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · daily-production-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/daily-production-th.png) |
| [docs/images/difficulty-continue-th.png](docs/images/difficulty-continue-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · difficulty-continue-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/difficulty-continue-th.png) |
| [docs/images/difficulty-game-en.png](docs/images/difficulty-game-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · difficulty-game-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/difficulty-game-en.png) |
| [docs/images/difficulty-setup-en.png](docs/images/difficulty-setup-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · difficulty-setup-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/difficulty-setup-en.png) |
| [docs/images/difficulty-setup-th.png](docs/images/difficulty-setup-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · difficulty-setup-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/difficulty-setup-th.png) |
| [docs/images/end-turn-harvest-review-en.png](docs/images/end-turn-harvest-review-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · end-turn-harvest-review-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/end-turn-harvest-review-en.png) |
| [docs/images/end-turn-receipt-th.png](docs/images/end-turn-receipt-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · end-turn-receipt-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/end-turn-receipt-th.png) |
| [docs/images/end-turn-review-th.png](docs/images/end-turn-review-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · end-turn-review-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/end-turn-review-th.png) |
| [docs/images/feedback-command-th.png](docs/images/feedback-command-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · feedback-command-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/feedback-command-th.png) |
| [docs/images/feedback-motion-en.png](docs/images/feedback-motion-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · feedback-motion-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/feedback-motion-en.png) |
| [docs/images/feedback-turn-en.png](docs/images/feedback-turn-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · feedback-turn-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/feedback-turn-en.png) |
| [docs/images/food-plan-balanced-en.png](docs/images/food-plan-balanced-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · food-plan-balanced-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/food-plan-balanced-en.png) |
| [docs/images/food-plan-balanced-th.png](docs/images/food-plan-balanced-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · food-plan-balanced-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/food-plan-balanced-th.png) |
| [docs/images/food-plan-hall-loss-en.png](docs/images/food-plan-hall-loss-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · food-plan-hall-loss-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/food-plan-hall-loss-en.png) |
| [docs/images/food-plan-hall-loss-th.png](docs/images/food-plan-hall-loss-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · food-plan-hall-loss-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/food-plan-hall-loss-th.png) |
| [docs/images/food-plan-harvest-en.png](docs/images/food-plan-harvest-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · food-plan-harvest-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/food-plan-harvest-en.png) |
| [docs/images/food-plan-harvest-th.png](docs/images/food-plan-harvest-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · food-plan-harvest-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/food-plan-harvest-th.png) |
| [docs/images/graphic-menu-th.png](docs/images/graphic-menu-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · graphic-menu-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/graphic-menu-th.png) |
| [docs/images/graphic-setup-en.png](docs/images/graphic-setup-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · graphic-setup-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/graphic-setup-en.png) |
| [docs/images/irrigation-history-th.png](docs/images/irrigation-history-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · irrigation-history-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/irrigation-history-th.png) |
| [docs/images/irrigation-planning-en.png](docs/images/irrigation-planning-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · irrigation-planning-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/irrigation-planning-en.png) |
| [docs/images/irrigation-planning-th.png](docs/images/irrigation-planning-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · irrigation-planning-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/irrigation-planning-th.png) |
| [docs/images/khung-don-village-concept.png](docs/images/khung-don-village-concept.png) | ภาพประกอบเอกสาร · ภาพ PNG · khung-don-village-concept.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/khung-don-village-concept.png) |
| [docs/images/ledger-growth-en.png](docs/images/ledger-growth-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · ledger-growth-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/ledger-growth-en.png) |
| [docs/images/ledger-harvest-th.png](docs/images/ledger-harvest-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · ledger-harvest-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/ledger-harvest-th.png) |
| [docs/images/ledger-zero-net-th.png](docs/images/ledger-zero-net-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · ledger-zero-net-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/ledger-zero-net-th.png) |
| [docs/images/living-detail-fixture-en.png](docs/images/living-detail-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · living-detail-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/living-detail-fixture-en.png) |
| [docs/images/living-flow-fixture-en.png](docs/images/living-flow-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · living-flow-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/living-flow-fixture-en.png) |
| [docs/images/living-growth-fixture-en.png](docs/images/living-growth-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · living-growth-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/living-growth-fixture-en.png) |
| [docs/images/living-risk-fixture-th.png](docs/images/living-risk-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · living-risk-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/living-risk-fixture-th.png) |
| [docs/images/living-start-th.png](docs/images/living-start-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · living-start-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/living-start-th.png) |
| [docs/images/living-work-fixture-en.png](docs/images/living-work-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · living-work-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/living-work-fixture-en.png) |
| [docs/images/long-setup-th.png](docs/images/long-setup-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · long-setup-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/long-setup-th.png) |
| [docs/images/long-waterwheel-th.png](docs/images/long-waterwheel-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · long-waterwheel-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/long-waterwheel-th.png) |
| [docs/images/long-win-fixture-en.png](docs/images/long-win-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · long-win-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/long-win-fixture-en.png) |
| [docs/images/m4-game-th.png](docs/images/m4-game-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-game-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-game-th.png) |
| [docs/images/m4-harvest-forecast-th.png](docs/images/m4-harvest-forecast-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-harvest-forecast-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-harvest-forecast-th.png) |
| [docs/images/m4-harvest-th.png](docs/images/m4-harvest-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-harvest-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-harvest-th.png) |
| [docs/images/m4-loss-confirm-fixture-en.png](docs/images/m4-loss-confirm-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-loss-confirm-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-loss-confirm-fixture-en.png) |
| [docs/images/m4-menu-th.png](docs/images/m4-menu-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-menu-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-menu-th.png) |
| [docs/images/m4-redo-en.png](docs/images/m4-redo-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-redo-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-redo-en.png) |
| [docs/images/m4-redo-th.png](docs/images/m4-redo-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-redo-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-redo-th.png) |
| [docs/images/m4-tile-danger-th.png](docs/images/m4-tile-danger-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-tile-danger-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-tile-danger-th.png) |
| [docs/images/m4-tile-production-en.png](docs/images/m4-tile-production-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-tile-production-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-tile-production-en.png) |
| [docs/images/m4-turn-results-fixture-en.png](docs/images/m4-turn-results-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-turn-results-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-turn-results-fixture-en.png) |
| [docs/images/m4-turn-results-fixture-th.png](docs/images/m4-turn-results-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-turn-results-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-turn-results-fixture-th.png) |
| [docs/images/m4-turn-results-harvest-fixture-en.png](docs/images/m4-turn-results-harvest-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · m4-turn-results-harvest-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/m4-turn-results-harvest-fixture-en.png) |
| [docs/images/moisture-dry-fixture-en.png](docs/images/moisture-dry-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-dry-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-dry-fixture-en.png) |
| [docs/images/moisture-dry-fixture-th.png](docs/images/moisture-dry-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-dry-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-dry-fixture-th.png) |
| [docs/images/moisture-pause-fixture-en.png](docs/images/moisture-pause-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-pause-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-pause-fixture-en.png) |
| [docs/images/moisture-pause-fixture-th.png](docs/images/moisture-pause-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-pause-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-pause-fixture-th.png) |
| [docs/images/moisture-rain-fixture-en.png](docs/images/moisture-rain-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-rain-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-rain-fixture-en.png) |
| [docs/images/moisture-rain-fixture-th.png](docs/images/moisture-rain-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-rain-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-rain-fixture-th.png) |
| [docs/images/moisture-setup-en.png](docs/images/moisture-setup-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-setup-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-setup-en.png) |
| [docs/images/moisture-setup-th.png](docs/images/moisture-setup-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-setup-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-setup-th.png) |
| [docs/images/moisture-yield-fixture-en.png](docs/images/moisture-yield-fixture-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-yield-fixture-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-yield-fixture-en.png) |
| [docs/images/moisture-yield-fixture-th.png](docs/images/moisture-yield-fixture-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · moisture-yield-fixture-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/moisture-yield-fixture-th.png) |
| [docs/images/resource-gains-th.png](docs/images/resource-gains-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · resource-gains-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/resource-gains-th.png) |
| [docs/images/resource-harvest-losses-en.png](docs/images/resource-harvest-losses-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · resource-harvest-losses-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/resource-harvest-losses-en.png) |
| [docs/images/resource-reduced-motion-th.png](docs/images/resource-reduced-motion-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · resource-reduced-motion-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/resource-reduced-motion-th.png) |
| [docs/images/sai-huan-world-concept.png](docs/images/sai-huan-world-concept.png) | ภาพประกอบเอกสาร · ภาพ PNG · sai-huan-world-concept.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/sai-huan-world-concept.png) |
| [docs/images/school-choose-en.png](docs/images/school-choose-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-choose-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-choose-en.png) |
| [docs/images/school-choose-th.png](docs/images/school-choose-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-choose-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-choose-th.png) |
| [docs/images/school-failure-en.png](docs/images/school-failure-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-failure-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-failure-en.png) |
| [docs/images/school-failure-th.png](docs/images/school-failure-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-failure-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-failure-th.png) |
| [docs/images/school-first-success-en.png](docs/images/school-first-success-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-first-success-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-first-success-en.png) |
| [docs/images/school-first-success-th.png](docs/images/school-first-success-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-first-success-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-first-success-th.png) |
| [docs/images/school-food-mastery-en.png](docs/images/school-food-mastery-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-food-mastery-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-food-mastery-en.png) |
| [docs/images/school-food-mastery-th.png](docs/images/school-food-mastery-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-food-mastery-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-food-mastery-th.png) |
| [docs/images/school-hint-en.png](docs/images/school-hint-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-hint-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-hint-en.png) |
| [docs/images/school-hint-th.png](docs/images/school-hint-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-hint-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-hint-th.png) |
| [docs/images/school-pause-en.png](docs/images/school-pause-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-pause-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-pause-en.png) |
| [docs/images/school-pause-th.png](docs/images/school-pause-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-pause-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-pause-th.png) |
| [docs/images/school-share-start-th.png](docs/images/school-share-start-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-share-start-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-share-start-th.png) |
| [docs/images/school-share-success-en.png](docs/images/school-share-success-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-share-success-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-share-success-en.png) |
| [docs/images/school-share-success-th.png](docs/images/school-share-success-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · school-share-success-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/school-share-success-th.png) |
| [docs/images/seasonal-mechanics-concept.png](docs/images/seasonal-mechanics-concept.png) | ภาพประกอบเอกสาร · ภาพ PNG · seasonal-mechanics-concept.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/seasonal-mechanics-concept.png) |
| [docs/images/survival-balance-setup-en.png](docs/images/survival-balance-setup-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · survival-balance-setup-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/survival-balance-setup-en.png) |
| [docs/images/survival-balance-setup-th.png](docs/images/survival-balance-setup-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · survival-balance-setup-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/survival-balance-setup-th.png) |
| [docs/images/transport-blocked-th.png](docs/images/transport-blocked-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · transport-blocked-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/transport-blocked-th.png) |
| [docs/images/transport-complete-en.png](docs/images/transport-complete-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · transport-complete-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/transport-complete-en.png) |
| [docs/images/transport-initial-th.png](docs/images/transport-initial-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · transport-initial-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/transport-initial-th.png) |
| [docs/images/transport-transit-th.png](docs/images/transport-transit-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · transport-transit-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/transport-transit-th.png) |
| [docs/images/turn-location-damage-th.png](docs/images/turn-location-damage-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · turn-location-damage-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/turn-location-damage-th.png) |
| [docs/images/turn-location-rice-en.png](docs/images/turn-location-rice-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · turn-location-rice-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/turn-location-rice-en.png) |
| [docs/images/turn-locations-report-th.png](docs/images/turn-locations-report-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · turn-locations-report-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/turn-locations-report-th.png) |
| [docs/images/visual-menu-th.png](docs/images/visual-menu-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · visual-menu-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/visual-menu-th.png) |
| [docs/images/visual-play-th.png](docs/images/visual-play-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · visual-play-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/visual-play-th.png) |
| [docs/images/visual-rain-en.png](docs/images/visual-rain-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · visual-rain-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/visual-rain-en.png) |
| [docs/images/world-riverbank-detail.png](docs/images/world-riverbank-detail.png) | ภาพประกอบเอกสาร · ภาพ PNG · world-riverbank-detail.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/world-riverbank-detail.png) |
| [docs/images/world-village-before.png](docs/images/world-village-before.png) | ภาพประกอบเอกสาร · ภาพ PNG · world-village-before.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/world-village-before.png) |
| [docs/images/world-village-dry.png](docs/images/world-village-dry.png) | ภาพประกอบเอกสาร · ภาพ PNG · world-village-dry.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/world-village-dry.png) |
| [docs/images/world-village-flood.png](docs/images/world-village-flood.png) | ภาพประกอบเอกสาร · ภาพ PNG · world-village-flood.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/world-village-flood.png) |
| [docs/images/world-village-rain.png](docs/images/world-village-rain.png) | ภาพประกอบเอกสาร · ภาพ PNG · world-village-rain.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/world-village-rain.png) |
| [docs/images/year-expansion-complete-en.png](docs/images/year-expansion-complete-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · year-expansion-complete-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/year-expansion-complete-en.png) |
| [docs/images/year-expansion-complete-th.png](docs/images/year-expansion-complete-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · year-expansion-complete-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/year-expansion-complete-th.png) |
| [docs/images/year-expansion-village-en.png](docs/images/year-expansion-village-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · year-expansion-village-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/year-expansion-village-en.png) |
| [docs/images/year-expansion-village-th.png](docs/images/year-expansion-village-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · year-expansion-village-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/year-expansion-village-th.png) |
| [docs/images/year365-complete-en.png](docs/images/year365-complete-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · year365-complete-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/year365-complete-en.png) |
| [docs/images/year365-complete-th.png](docs/images/year365-complete-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · year365-complete-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/year365-complete-th.png) |
| [docs/images/year365-flood-en.png](docs/images/year365-flood-en.png) | ภาพประกอบเอกสาร · ภาพ PNG · year365-flood-en.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/year365-flood-en.png) |
| [docs/images/year365-flood-th.png](docs/images/year365-flood-th.png) | ภาพประกอบเอกสาร · ภาพ PNG · year365-flood-th.png | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/images/year365-flood-th.png) |

### `docs/reference/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reference/claude-code-gdd.md](docs/reference/claude-code-gdd.md) | ฤดูน้ำหลาก (Monsoon Delta) | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reference/claude-code-gdd.md) |
| [docs/reference/claude-code-specs.md](docs/reference/claude-code-specs.md) | ฤดูน้ำหลาก (Monsoon Delta) | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reference/claude-code-specs.md) |
| [docs/reference/proposed-layout.txt](docs/reference/proposed-layout.txt) | ข้อความ/ตัวอย่างอ้างอิง · proposed-layout.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reference/proposed-layout.txt) |

### `docs/reports/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/architecture-living-qa-en.json](docs/reports/architecture-living-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · architecture-living-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/architecture-living-qa-en.json) |
| [docs/reports/architecture-living-qa-th.json](docs/reports/architecture-living-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · architecture-living-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/architecture-living-qa-th.json) |
| [docs/reports/architecture-qa.json](docs/reports/architecture-qa.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · architecture-qa.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/architecture-qa.json) |
| [docs/reports/area-development-qa-en.json](docs/reports/area-development-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · area-development-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/area-development-qa-en.json) |
| [docs/reports/area-development-qa-th.json](docs/reports/area-development-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · area-development-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/area-development-qa-th.json) |
| [docs/reports/bracing-qa-en.json](docs/reports/bracing-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · bracing-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/bracing-qa-en.json) |
| [docs/reports/bracing-qa-th.json](docs/reports/bracing-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · bracing-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/bracing-qa-th.json) |
| [docs/reports/continue-summary-qa-en.json](docs/reports/continue-summary-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · continue-summary-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/continue-summary-qa-en.json) |
| [docs/reports/continue-summary-qa-th.json](docs/reports/continue-summary-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · continue-summary-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/continue-summary-qa-th.json) |
| [docs/reports/daily-production-qa-en.json](docs/reports/daily-production-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · daily-production-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/daily-production-qa-en.json) |
| [docs/reports/daily-production-qa-th.json](docs/reports/daily-production-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · daily-production-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/daily-production-qa-th.json) |
| [docs/reports/end-turn-qa-en.json](docs/reports/end-turn-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · end-turn-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/end-turn-qa-en.json) |
| [docs/reports/end-turn-qa-th.json](docs/reports/end-turn-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · end-turn-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/end-turn-qa-th.json) |
| [docs/reports/food-plan-qa-en.json](docs/reports/food-plan-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · food-plan-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/food-plan-qa-en.json) |
| [docs/reports/food-plan-qa-th.json](docs/reports/food-plan-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · food-plan-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/food-plan-qa-th.json) |
| [docs/reports/graphic-menu-draft-qa-en.json](docs/reports/graphic-menu-draft-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · graphic-menu-draft-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/graphic-menu-draft-qa-en.json) |
| [docs/reports/graphic-menu-draft-qa-th.json](docs/reports/graphic-menu-draft-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · graphic-menu-draft-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/graphic-menu-draft-qa-th.json) |
| [docs/reports/graphic-menu-qa.json](docs/reports/graphic-menu-qa.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · graphic-menu-qa.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/graphic-menu-qa.json) |
| [docs/reports/irrigation-qa-en.json](docs/reports/irrigation-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · irrigation-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/irrigation-qa-en.json) |
| [docs/reports/irrigation-qa-th.json](docs/reports/irrigation-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · irrigation-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/irrigation-qa-th.json) |
| [docs/reports/living-village-qa-en.json](docs/reports/living-village-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · living-village-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/living-village-qa-en.json) |
| [docs/reports/living-village-qa-th.json](docs/reports/living-village-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · living-village-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/living-village-qa-th.json) |
| [docs/reports/m3_balance_screen.csv](docs/reports/m3_balance_screen.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · m3_balance_screen.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_balance_screen.csv) |
| [docs/reports/m3_bots.csv](docs/reports/m3_bots.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · m3_bots.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_bots.csv) |
| [docs/reports/moisture-qa-en.json](docs/reports/moisture-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · moisture-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/moisture-qa-en.json) |
| [docs/reports/moisture-qa-th.json](docs/reports/moisture-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · moisture-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/moisture-qa-th.json) |
| [docs/reports/resource-feedback-qa-en.json](docs/reports/resource-feedback-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · resource-feedback-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/resource-feedback-qa-en.json) |
| [docs/reports/resource-feedback-qa-th.json](docs/reports/resource-feedback-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · resource-feedback-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/resource-feedback-qa-th.json) |
| [docs/reports/resource-ledger-qa-en.json](docs/reports/resource-ledger-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · resource-ledger-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/resource-ledger-qa-en.json) |
| [docs/reports/resource-ledger-qa-th.json](docs/reports/resource-ledger-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · resource-ledger-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/resource-ledger-qa-th.json) |
| [docs/reports/river-school-qa-en.json](docs/reports/river-school-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · river-school-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/river-school-qa-en.json) |
| [docs/reports/river-school-qa-th.json](docs/reports/river-school-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · river-school-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/river-school-qa-th.json) |
| [docs/reports/share-flow-qa-en.json](docs/reports/share-flow-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · share-flow-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/share-flow-qa-en.json) |
| [docs/reports/share-flow-qa-th.json](docs/reports/share-flow-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · share-flow-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/share-flow-qa-th.json) |
| [docs/reports/transport-qa-en.json](docs/reports/transport-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · transport-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/transport-qa-en.json) |
| [docs/reports/transport-qa-th.json](docs/reports/transport-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · transport-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/transport-qa-th.json) |
| [docs/reports/turn-result-inspection-qa-en.json](docs/reports/turn-result-inspection-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · turn-result-inspection-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/turn-result-inspection-qa-en.json) |
| [docs/reports/turn-result-inspection-qa-th.json](docs/reports/turn-result-inspection-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · turn-result-inspection-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/turn-result-inspection-qa-th.json) |
| [docs/reports/ui-context-menu-qa-en.json](docs/reports/ui-context-menu-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · ui-context-menu-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/ui-context-menu-qa-en.json) |
| [docs/reports/ui-context-menu-qa-th.json](docs/reports/ui-context-menu-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · ui-context-menu-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/ui-context-menu-qa-th.json) |
| [docs/reports/ui-context-school-qa-en.json](docs/reports/ui-context-school-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · ui-context-school-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/ui-context-school-qa-en.json) |
| [docs/reports/ui-context-school-qa-th.json](docs/reports/ui-context-school-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · ui-context-school-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/ui-context-school-qa-th.json) |
| [docs/reports/village-world-living-qa-en.json](docs/reports/village-world-living-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · village-world-living-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/village-world-living-qa-en.json) |
| [docs/reports/village-world-living-qa-th.json](docs/reports/village-world-living-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · village-world-living-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/village-world-living-qa-th.json) |
| [docs/reports/village-world-qa-en.json](docs/reports/village-world-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · village-world-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/village-world-qa-en.json) |
| [docs/reports/village-world-qa-th.json](docs/reports/village-world-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · village-world-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/village-world-qa-th.json) |
| [docs/reports/year-expansion-qa-en.json](docs/reports/year-expansion-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · year-expansion-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/year-expansion-qa-en.json) |
| [docs/reports/year-expansion-qa-th.json](docs/reports/year-expansion-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · year-expansion-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/year-expansion-qa-th.json) |
| [docs/reports/year-expansion-replays.json](docs/reports/year-expansion-replays.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · year-expansion-replays.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/year-expansion-replays.json) |
| [docs/reports/year365-qa-en.json](docs/reports/year365-qa-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · year365-qa-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/year365-qa-en.json) |
| [docs/reports/year365-qa-th.json](docs/reports/year365-qa-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · year365-qa-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/year365-qa-th.json) |

### `docs/reports/balanced_20261107/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/balanced_20261107/checker.txt](docs/reports/balanced_20261107/checker.txt) | หลักฐานย้อนหลัง · ข้อความ/ตัวอย่างอ้างอิง · checker.txt | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/checker.txt) |
| [docs/reports/balanced_20261107/menu-balanced-en.json](docs/reports/balanced_20261107/menu-balanced-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · menu-balanced-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/menu-balanced-en.json) |
| [docs/reports/balanced_20261107/menu-balanced-th.json](docs/reports/balanced_20261107/menu-balanced-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · menu-balanced-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/menu-balanced-th.json) |
| [docs/reports/balanced_20261107/menu-legacy-en.json](docs/reports/balanced_20261107/menu-legacy-en.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · menu-legacy-en.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/menu-legacy-en.json) |
| [docs/reports/balanced_20261107/menu-legacy-th.json](docs/reports/balanced_20261107/menu-legacy-th.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · menu-legacy-th.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/menu-legacy-th.json) |

### `docs/reports/balanced_20261107/farmer_d0/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/balanced_20261107/farmer_d0/.gdignore](docs/reports/balanced_20261107/farmer_d0/.gdignore) | หลักฐานย้อนหลัง · ไฟล์ตั้งค่า/ทรัพยากร · .gdignore | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/farmer_d0/.gdignore) |
| [docs/reports/balanced_20261107/farmer_d0/manifest.json](docs/reports/balanced_20261107/farmer_d0/manifest.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · manifest.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/farmer_d0/manifest.json) |
| [docs/reports/balanced_20261107/farmer_d0/summary.csv](docs/reports/balanced_20261107/farmer_d0/summary.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · summary.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/farmer_d0/summary.csv) |

### `docs/reports/balanced_20261107/farmer_d0/baseline/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/balanced_20261107/farmer_d0/baseline/farmer_plains_d0.csv](docs/reports/balanced_20261107/farmer_d0/baseline/farmer_plains_d0.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · farmer_plains_d0.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/farmer_d0/baseline/farmer_plains_d0.csv) |

### `docs/reports/balanced_20261107/greedy_d0/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/balanced_20261107/greedy_d0/.gdignore](docs/reports/balanced_20261107/greedy_d0/.gdignore) | หลักฐานย้อนหลัง · ไฟล์ตั้งค่า/ทรัพยากร · .gdignore | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/greedy_d0/.gdignore) |
| [docs/reports/balanced_20261107/greedy_d0/manifest.json](docs/reports/balanced_20261107/greedy_d0/manifest.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · manifest.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/greedy_d0/manifest.json) |
| [docs/reports/balanced_20261107/greedy_d0/summary.csv](docs/reports/balanced_20261107/greedy_d0/summary.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · summary.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/greedy_d0/summary.csv) |

### `docs/reports/balanced_20261107/greedy_d0/baseline/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/balanced_20261107/greedy_d0/baseline/greedy_plains_d0.csv](docs/reports/balanced_20261107/greedy_d0/baseline/greedy_plains_d0.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · greedy_plains_d0.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/greedy_d0/baseline/greedy_plains_d0.csv) |

### `docs/reports/balanced_20261107/greedy_d10/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/balanced_20261107/greedy_d10/.gdignore](docs/reports/balanced_20261107/greedy_d10/.gdignore) | หลักฐานย้อนหลัง · ไฟล์ตั้งค่า/ทรัพยากร · .gdignore | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/greedy_d10/.gdignore) |
| [docs/reports/balanced_20261107/greedy_d10/manifest.json](docs/reports/balanced_20261107/greedy_d10/manifest.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · manifest.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/greedy_d10/manifest.json) |
| [docs/reports/balanced_20261107/greedy_d10/summary.csv](docs/reports/balanced_20261107/greedy_d10/summary.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · summary.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/greedy_d10/summary.csv) |

### `docs/reports/balanced_20261107/greedy_d10/baseline/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/balanced_20261107/greedy_d10/baseline/greedy_plains_d10.csv](docs/reports/balanced_20261107/greedy_d10/baseline/greedy_plains_d10.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · greedy_plains_d10.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/balanced_20261107/greedy_d10/baseline/greedy_plains_d10.csv) |

### `docs/reports/m3_followup_20261017/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/m3_followup_20261017/screen_games.csv](docs/reports/m3_followup_20261017/screen_games.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · screen_games.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/screen_games.csv) |
| [docs/reports/m3_followup_20261017/screen_summary.csv](docs/reports/m3_followup_20261017/screen_summary.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · screen_summary.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/screen_summary.csv) |

### `docs/reports/m3_followup_20261017/farmer_d0/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/m3_followup_20261017/farmer_d0/manifest.json](docs/reports/m3_followup_20261017/farmer_d0/manifest.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · manifest.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/farmer_d0/manifest.json) |
| [docs/reports/m3_followup_20261017/farmer_d0/summary.csv](docs/reports/m3_followup_20261017/farmer_d0/summary.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · summary.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/farmer_d0/summary.csv) |

### `docs/reports/m3_followup_20261017/farmer_d0/h5_g3/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/m3_followup_20261017/farmer_d0/h5_g3/farmer_plains_d0.csv](docs/reports/m3_followup_20261017/farmer_d0/h5_g3/farmer_plains_d0.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · farmer_plains_d0.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/farmer_d0/h5_g3/farmer_plains_d0.csv) |

### `docs/reports/m3_followup_20261017/greedy_d0/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/m3_followup_20261017/greedy_d0/manifest.json](docs/reports/m3_followup_20261017/greedy_d0/manifest.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · manifest.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/greedy_d0/manifest.json) |
| [docs/reports/m3_followup_20261017/greedy_d0/summary.csv](docs/reports/m3_followup_20261017/greedy_d0/summary.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · summary.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/greedy_d0/summary.csv) |

### `docs/reports/m3_followup_20261017/greedy_d0/h5_g3/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/m3_followup_20261017/greedy_d0/h5_g3/greedy_plains_d0.csv](docs/reports/m3_followup_20261017/greedy_d0/h5_g3/greedy_plains_d0.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · greedy_plains_d0.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/greedy_d0/h5_g3/greedy_plains_d0.csv) |

### `docs/reports/m3_followup_20261017/greedy_d10/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/m3_followup_20261017/greedy_d10/manifest.json](docs/reports/m3_followup_20261017/greedy_d10/manifest.json) | หลักฐานย้อนหลัง · ข้อมูล JSON · manifest.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/greedy_d10/manifest.json) |
| [docs/reports/m3_followup_20261017/greedy_d10/summary.csv](docs/reports/m3_followup_20261017/greedy_d10/summary.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · summary.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/greedy_d10/summary.csv) |

### `docs/reports/m3_followup_20261017/greedy_d10/h5_g3/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/reports/m3_followup_20261017/greedy_d10/h5_g3/greedy_plains_d10.csv](docs/reports/m3_followup_20261017/greedy_d10/h5_g3/greedy_plains_d10.csv) | หลักฐานย้อนหลัง · ข้อมูลตาราง CSV · greedy_plains_d10.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/reports/m3_followup_20261017/greedy_d10/h5_g3/greedy_plains_d10.csv) |

### `docs/specs/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [docs/specs/00_README.md](docs/specs/00_README.md) | 00 README: วิธีอ่านสเปก | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/00_README.md) |
| [docs/specs/01_architecture.md](docs/specs/01_architecture.md) | 01 สถาปัตยกรรม | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/01_architecture.md) |
| [docs/specs/02_state_save.md](docs/specs/02_state_save.md) | 02 สถานะเกม การบันทึก และ undo | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/02_state_save.md) |
| [docs/specs/04_water.md](docs/specs/04_water.md) | 04 ระบบน้ำ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/04_water.md) |
| [docs/specs/05_commands.md](docs/specs/05_commands.md) | 05 คำสั่งของผู้เล่น | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/05_commands.md) |
| [docs/specs/06_turn_flow.md](docs/specs/06_turn_flow.md) | 06 ลำดับเกม | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/06_turn_flow.md) |
| [docs/specs/07_mods_cards_leaders.md](docs/specs/07_mods_cards_leaders.md) | 07 Modifier การ์ด ผู้ใหญ่บ้าน แผนที่ และความยาก | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/07_mods_cards_leaders.md) |
| [docs/specs/08_events.md](docs/specs/08_events.md) | 08 เหตุการณ์สุ่ม (data/events.json) | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/08_events.md) |
| [docs/specs/09_meta.md](docs/specs/09_meta.md) | 09 คะแนน โปรไฟล์ ปลดล็อก และท้าทายรายวัน | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/09_meta.md) |
| [docs/specs/10_ui.md](docs/specs/10_ui.md) | 10 UI/UX | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/10_ui.md) |
| [docs/specs/11_visuals.md](docs/specs/11_visuals.md) | 11 ภาพ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/11_visuals.md) |
| [docs/specs/12_audio.md](docs/specs/12_audio.md) | 12 เสียง | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/12_audio.md) |
| [docs/specs/13_i18n.md](docs/specs/13_i18n.md) | 13 ภาษาและฟอนต์ | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/13_i18n.md) |
| [docs/specs/14_testing_bot.md](docs/specs/14_testing_bot.md) | 14 เทสต์และบอท | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/14_testing_bot.md) |
| [docs/specs/15_technical_reference.md](docs/specs/15_technical_reference.md) | 15 ดัชนีตัวอย่างเทคนิค | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/docs/specs/15_technical_reference.md) |

### `scripts/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [scripts/check_balance.py](scripts/check_balance.py) | เครื่องมือ Python · check_balance.py | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/scripts/check_balance.py) |
| [scripts/check_docs.py](scripts/check_docs.py) | เครื่องมือ Python · check_docs.py | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/scripts/check_docs.py) |
| [scripts/test.sh](scripts/test.sh) | สคริปต์ Shell · test.sh | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/scripts/test.sh) |
| [scripts/test_balance_cli.py](scripts/test_balance_cli.py) | เครื่องมือ Python · test_balance_cli.py | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/scripts/test_balance_cli.py) |
| [scripts/test_boot_cli.py](scripts/test_boot_cli.py) | เครื่องมือ Python · test_boot_cli.py | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/scripts/test_boot_cli.py) |
| [scripts/test_check_balance.py](scripts/test_check_balance.py) | เครื่องมือ Python · test_check_balance.py | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/scripts/test_check_balance.py) |
| [scripts/test_school_cli.py](scripts/test_school_cli.py) | เครื่องมือ Python · test_school_cli.py | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/scripts/test_school_cli.py) |
| [scripts/update_file_index.py](scripts/update_file_index.py) | เครื่องมือ Python · update_file_index.py | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/scripts/update_file_index.py) |

### `tests/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [tests/run_tests.gd](tests/run_tests.gd) | การทดสอบ · สคริปต์ GDScript · run_tests.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/run_tests.gd) |
| [tests/run_tests.gd.uid](tests/run_tests.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · run_tests.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/run_tests.gd.uid) |
| [tests/test_action_feedback.gd](tests/test_action_feedback.gd) | การทดสอบ · สคริปต์ GDScript · test_action_feedback.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_action_feedback.gd) |
| [tests/test_action_feedback.gd.uid](tests/test_action_feedback.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_action_feedback.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_action_feedback.gd.uid) |
| [tests/test_area_development.gd](tests/test_area_development.gd) | การทดสอบ · สคริปต์ GDScript · test_area_development.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_area_development.gd) |
| [tests/test_area_development.gd.uid](tests/test_area_development.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_area_development.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_area_development.gd.uid) |
| [tests/test_area_development_ui.gd](tests/test_area_development_ui.gd) | การทดสอบ · สคริปต์ GDScript · test_area_development_ui.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_area_development_ui.gd) |
| [tests/test_area_development_ui.gd.uid](tests/test_area_development_ui.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_area_development_ui.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_area_development_ui.gd.uid) |
| [tests/test_balance_scenarios.gd](tests/test_balance_scenarios.gd) | การทดสอบ · สคริปต์ GDScript · test_balance_scenarios.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_balance_scenarios.gd) |
| [tests/test_balance_scenarios.gd.uid](tests/test_balance_scenarios.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_balance_scenarios.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_balance_scenarios.gd.uid) |
| [tests/test_balanced_ruleset.gd](tests/test_balanced_ruleset.gd) | การทดสอบ · สคริปต์ GDScript · test_balanced_ruleset.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_balanced_ruleset.gd) |
| [tests/test_balanced_ruleset.gd.uid](tests/test_balanced_ruleset.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_balanced_ruleset.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_balanced_ruleset.gd.uid) |
| [tests/test_board_view.gd](tests/test_board_view.gd) | การทดสอบ · สคริปต์ GDScript · test_board_view.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_board_view.gd) |
| [tests/test_board_view.gd.uid](tests/test_board_view.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_board_view.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_board_view.gd.uid) |
| [tests/test_bracing.gd](tests/test_bracing.gd) | การทดสอบ · สคริปต์ GDScript · test_bracing.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_bracing.gd) |
| [tests/test_bracing.gd.uid](tests/test_bracing.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_bracing.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_bracing.gd.uid) |
| [tests/test_bracing_save.gd](tests/test_bracing_save.gd) | การทดสอบ · สคริปต์ GDScript · test_bracing_save.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_bracing_save.gd) |
| [tests/test_bracing_save.gd.uid](tests/test_bracing_save.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_bracing_save.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_bracing_save.gd.uid) |
| [tests/test_bracing_ui.gd](tests/test_bracing_ui.gd) | การทดสอบ · สคริปต์ GDScript · test_bracing_ui.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_bracing_ui.gd) |
| [tests/test_bracing_ui.gd.uid](tests/test_bracing_ui.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_bracing_ui.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_bracing_ui.gd.uid) |
| [tests/test_bracing_view.gd](tests/test_bracing_view.gd) | การทดสอบ · สคริปต์ GDScript · test_bracing_view.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_bracing_view.gd) |
| [tests/test_bracing_view.gd.uid](tests/test_bracing_view.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_bracing_view.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_bracing_view.gd.uid) |
| [tests/test_building_architecture.gd](tests/test_building_architecture.gd) | การทดสอบ · สคริปต์ GDScript · test_building_architecture.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_building_architecture.gd) |
| [tests/test_building_architecture.gd.uid](tests/test_building_architecture.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_building_architecture.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_building_architecture.gd.uid) |
| [tests/test_case.gd](tests/test_case.gd) | การทดสอบ · สคริปต์ GDScript · test_case.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_case.gd) |
| [tests/test_case.gd.uid](tests/test_case.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_case.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_case.gd.uid) |
| [tests/test_commands.gd](tests/test_commands.gd) | การทดสอบ · สคริปต์ GDScript · test_commands.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_commands.gd) |
| [tests/test_commands.gd.uid](tests/test_commands.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_commands.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_commands.gd.uid) |
| [tests/test_continue_summary.gd](tests/test_continue_summary.gd) | การทดสอบ · สคริปต์ GDScript · test_continue_summary.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_continue_summary.gd) |
| [tests/test_continue_summary.gd.uid](tests/test_continue_summary.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_continue_summary.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_continue_summary.gd.uid) |
| [tests/test_daily_production.gd](tests/test_daily_production.gd) | การทดสอบ · สคริปต์ GDScript · test_daily_production.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_daily_production.gd) |
| [tests/test_daily_production.gd.uid](tests/test_daily_production.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_daily_production.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_daily_production.gd.uid) |
| [tests/test_daily_session.gd](tests/test_daily_session.gd) | การทดสอบ · สคริปต์ GDScript · test_daily_session.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_daily_session.gd) |
| [tests/test_daily_session.gd.uid](tests/test_daily_session.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_daily_session.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_daily_session.gd.uid) |
| [tests/test_determinism.gd](tests/test_determinism.gd) | การทดสอบ · สคริปต์ GDScript · test_determinism.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_determinism.gd) |
| [tests/test_determinism.gd.uid](tests/test_determinism.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_determinism.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_determinism.gd.uid) |
| [tests/test_difficulty_hud.gd](tests/test_difficulty_hud.gd) | การทดสอบ · สคริปต์ GDScript · test_difficulty_hud.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_difficulty_hud.gd) |
| [tests/test_difficulty_hud.gd.uid](tests/test_difficulty_hud.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_difficulty_hud.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_difficulty_hud.gd.uid) |
| [tests/test_end_turn_flow.gd](tests/test_end_turn_flow.gd) | การทดสอบ · สคริปต์ GDScript · test_end_turn_flow.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_end_turn_flow.gd) |
| [tests/test_end_turn_flow.gd.uid](tests/test_end_turn_flow.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_end_turn_flow.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_end_turn_flow.gd.uid) |
| [tests/test_flow.gd](tests/test_flow.gd) | การทดสอบ · สคริปต์ GDScript · test_flow.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_flow.gd) |
| [tests/test_flow.gd.uid](tests/test_flow.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_flow.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_flow.gd.uid) |
| [tests/test_food_plan.gd](tests/test_food_plan.gd) | การทดสอบ · สคริปต์ GDScript · test_food_plan.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_food_plan.gd) |
| [tests/test_food_plan.gd.uid](tests/test_food_plan.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_food_plan.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_food_plan.gd.uid) |
| [tests/test_forecast.gd](tests/test_forecast.gd) | การทดสอบ · สคริปต์ GDScript · test_forecast.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_forecast.gd) |
| [tests/test_forecast.gd.uid](tests/test_forecast.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_forecast.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_forecast.gd.uid) |
| [tests/test_game_screen.gd](tests/test_game_screen.gd) | การทดสอบ · สคริปต์ GDScript · test_game_screen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_game_screen.gd) |
| [tests/test_game_screen.gd.uid](tests/test_game_screen.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_game_screen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_game_screen.gd.uid) |
| [tests/test_harvest.gd](tests/test_harvest.gd) | การทดสอบ · สคริปต์ GDScript · test_harvest.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_harvest.gd) |
| [tests/test_harvest.gd.uid](tests/test_harvest.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_harvest.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_harvest.gd.uid) |
| [tests/test_hex.gd](tests/test_hex.gd) | การทดสอบ · สคริปต์ GDScript · test_hex.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_hex.gd) |
| [tests/test_hex.gd.uid](tests/test_hex.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_hex.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_hex.gd.uid) |
| [tests/test_i18n.gd](tests/test_i18n.gd) | การทดสอบ · สคริปต์ GDScript · test_i18n.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_i18n.gd) |
| [tests/test_i18n.gd.uid](tests/test_i18n.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_i18n.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_i18n.gd.uid) |
| [tests/test_irrigation.gd](tests/test_irrigation.gd) | การทดสอบ · สคริปต์ GDScript · test_irrigation.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_irrigation.gd) |
| [tests/test_irrigation.gd.uid](tests/test_irrigation.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_irrigation.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_irrigation.gd.uid) |
| [tests/test_irrigation_save.gd](tests/test_irrigation_save.gd) | การทดสอบ · สคริปต์ GDScript · test_irrigation_save.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_irrigation_save.gd) |
| [tests/test_irrigation_save.gd.uid](tests/test_irrigation_save.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_irrigation_save.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_irrigation_save.gd.uid) |
| [tests/test_irrigation_ui.gd](tests/test_irrigation_ui.gd) | การทดสอบ · สคริปต์ GDScript · test_irrigation_ui.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_irrigation_ui.gd) |
| [tests/test_irrigation_ui.gd.uid](tests/test_irrigation_ui.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_irrigation_ui.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_irrigation_ui.gd.uid) |
| [tests/test_living_board.gd](tests/test_living_board.gd) | การทดสอบ · สคริปต์ GDScript · test_living_board.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_living_board.gd) |
| [tests/test_living_board.gd.uid](tests/test_living_board.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_living_board.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_living_board.gd.uid) |
| [tests/test_long_hud.gd](tests/test_long_hud.gd) | การทดสอบ · สคริปต์ GDScript · test_long_hud.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_long_hud.gd) |
| [tests/test_long_hud.gd.uid](tests/test_long_hud.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_long_hud.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_long_hud.gd.uid) |
| [tests/test_long_menu.gd](tests/test_long_menu.gd) | การทดสอบ · สคริปต์ GDScript · test_long_menu.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_long_menu.gd) |
| [tests/test_long_menu.gd.uid](tests/test_long_menu.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_long_menu.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_long_menu.gd.uid) |
| [tests/test_long_runs.gd](tests/test_long_runs.gd) | การทดสอบ · สคริปต์ GDScript · test_long_runs.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_long_runs.gd) |
| [tests/test_long_runs.gd.uid](tests/test_long_runs.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_long_runs.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_long_runs.gd.uid) |
| [tests/test_long_save.gd](tests/test_long_save.gd) | การทดสอบ · สคริปต์ GDScript · test_long_save.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_long_save.gd) |
| [tests/test_long_save.gd.uid](tests/test_long_save.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_long_save.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_long_save.gd.uid) |
| [tests/test_map_gen.gd](tests/test_map_gen.gd) | การทดสอบ · สคริปต์ GDScript · test_map_gen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_map_gen.gd) |
| [tests/test_map_gen.gd.uid](tests/test_map_gen.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_map_gen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_map_gen.gd.uid) |
| [tests/test_maps.gd](tests/test_maps.gd) | การทดสอบ · สคริปต์ GDScript · test_maps.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_maps.gd) |
| [tests/test_maps.gd.uid](tests/test_maps.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_maps.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_maps.gd.uid) |
| [tests/test_menu.gd](tests/test_menu.gd) | การทดสอบ · สคริปต์ GDScript · test_menu.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_menu.gd) |
| [tests/test_menu.gd.uid](tests/test_menu.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_menu.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_menu.gd.uid) |
| [tests/test_moisture.gd](tests/test_moisture.gd) | การทดสอบ · สคริปต์ GDScript · test_moisture.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_moisture.gd) |
| [tests/test_moisture.gd.uid](tests/test_moisture.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_moisture.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_moisture.gd.uid) |
| [tests/test_moisture_save.gd](tests/test_moisture_save.gd) | การทดสอบ · สคริปต์ GDScript · test_moisture_save.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_moisture_save.gd) |
| [tests/test_moisture_save.gd.uid](tests/test_moisture_save.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_moisture_save.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_moisture_save.gd.uid) |
| [tests/test_moisture_ui.gd](tests/test_moisture_ui.gd) | การทดสอบ · สคริปต์ GDScript · test_moisture_ui.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_moisture_ui.gd) |
| [tests/test_moisture_ui.gd.uid](tests/test_moisture_ui.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_moisture_ui.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_moisture_ui.gd.uid) |
| [tests/test_moisture_view.gd](tests/test_moisture_view.gd) | การทดสอบ · สคริปต์ GDScript · test_moisture_view.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_moisture_view.gd) |
| [tests/test_moisture_view.gd.uid](tests/test_moisture_view.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_moisture_view.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_moisture_view.gd.uid) |
| [tests/test_planning_feedback.gd](tests/test_planning_feedback.gd) | การทดสอบ · สคริปต์ GDScript · test_planning_feedback.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_planning_feedback.gd) |
| [tests/test_planning_feedback.gd.uid](tests/test_planning_feedback.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_planning_feedback.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_planning_feedback.gd.uid) |
| [tests/test_preferences.gd](tests/test_preferences.gd) | การทดสอบ · สคริปต์ GDScript · test_preferences.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_preferences.gd) |
| [tests/test_preferences.gd.uid](tests/test_preferences.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_preferences.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_preferences.gd.uid) |
| [tests/test_preview.gd](tests/test_preview.gd) | การทดสอบ · สคริปต์ GDScript · test_preview.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_preview.gd) |
| [tests/test_preview.gd.uid](tests/test_preview.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_preview.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_preview.gd.uid) |
| [tests/test_reduced_motion.gd](tests/test_reduced_motion.gd) | การทดสอบ · สคริปต์ GDScript · test_reduced_motion.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_reduced_motion.gd) |
| [tests/test_reduced_motion.gd.uid](tests/test_reduced_motion.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_reduced_motion.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_reduced_motion.gd.uid) |
| [tests/test_resource_feedback.gd](tests/test_resource_feedback.gd) | การทดสอบ · สคริปต์ GDScript · test_resource_feedback.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_resource_feedback.gd) |
| [tests/test_resource_feedback.gd.uid](tests/test_resource_feedback.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_resource_feedback.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_resource_feedback.gd.uid) |
| [tests/test_resource_ledger.gd](tests/test_resource_ledger.gd) | การทดสอบ · สคริปต์ GDScript · test_resource_ledger.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_resource_ledger.gd) |
| [tests/test_resource_ledger.gd.uid](tests/test_resource_ledger.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_resource_ledger.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_resource_ledger.gd.uid) |
| [tests/test_river_school_fixtures.gd](tests/test_river_school_fixtures.gd) | การทดสอบ · สคริปต์ GDScript · test_river_school_fixtures.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_river_school_fixtures.gd) |
| [tests/test_river_school_fixtures.gd.uid](tests/test_river_school_fixtures.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_river_school_fixtures.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_river_school_fixtures.gd.uid) |
| [tests/test_river_school_menu.gd](tests/test_river_school_menu.gd) | การทดสอบ · สคริปต์ GDScript · test_river_school_menu.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_river_school_menu.gd) |
| [tests/test_river_school_menu.gd.uid](tests/test_river_school_menu.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_river_school_menu.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_river_school_menu.gd.uid) |
| [tests/test_river_school_run.gd](tests/test_river_school_run.gd) | การทดสอบ · สคริปต์ GDScript · test_river_school_run.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_river_school_run.gd) |
| [tests/test_river_school_run.gd.uid](tests/test_river_school_run.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_river_school_run.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_river_school_run.gd.uid) |
| [tests/test_river_school_screen.gd](tests/test_river_school_screen.gd) | การทดสอบ · สคริปต์ GDScript · test_river_school_screen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_river_school_screen.gd) |
| [tests/test_river_school_screen.gd.uid](tests/test_river_school_screen.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_river_school_screen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_river_school_screen.gd.uid) |
| [tests/test_route_graph.gd](tests/test_route_graph.gd) | การทดสอบ · สคริปต์ GDScript · test_route_graph.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_route_graph.gd) |
| [tests/test_route_graph.gd.uid](tests/test_route_graph.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_route_graph.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_route_graph.gd.uid) |
| [tests/test_sandbox.gd](tests/test_sandbox.gd) | การทดสอบ · สคริปต์ GDScript · test_sandbox.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_sandbox.gd) |
| [tests/test_sandbox.gd.uid](tests/test_sandbox.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_sandbox.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_sandbox.gd.uid) |
| [tests/test_save.gd](tests/test_save.gd) | การทดสอบ · สคริปต์ GDScript · test_save.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_save.gd) |
| [tests/test_save.gd.uid](tests/test_save.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_save.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_save.gd.uid) |
| [tests/test_save_continuation.gd](tests/test_save_continuation.gd) | การทดสอบ · สคริปต์ GDScript · test_save_continuation.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_save_continuation.gd) |
| [tests/test_save_continuation.gd.uid](tests/test_save_continuation.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_save_continuation.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_save_continuation.gd.uid) |
| [tests/test_scoring.gd](tests/test_scoring.gd) | การทดสอบ · สคริปต์ GDScript · test_scoring.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_scoring.gd) |
| [tests/test_scoring.gd.uid](tests/test_scoring.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_scoring.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_scoring.gd.uid) |
| [tests/test_screen_feedback.gd](tests/test_screen_feedback.gd) | การทดสอบ · สคริปต์ GDScript · test_screen_feedback.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_screen_feedback.gd) |
| [tests/test_screen_feedback.gd.uid](tests/test_screen_feedback.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_screen_feedback.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_screen_feedback.gd.uid) |
| [tests/test_seed.gd](tests/test_seed.gd) | การทดสอบ · สคริปต์ GDScript · test_seed.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_seed.gd) |
| [tests/test_seed.gd.uid](tests/test_seed.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_seed.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_seed.gd.uid) |
| [tests/test_session.gd](tests/test_session.gd) | การทดสอบ · สคริปต์ GDScript · test_session.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_session.gd) |
| [tests/test_session.gd.uid](tests/test_session.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_session.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_session.gd.uid) |
| [tests/test_settlement_progress.gd](tests/test_settlement_progress.gd) | การทดสอบ · สคริปต์ GDScript · test_settlement_progress.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_settlement_progress.gd) |
| [tests/test_settlement_progress.gd.uid](tests/test_settlement_progress.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_settlement_progress.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_settlement_progress.gd.uid) |
| [tests/test_state.gd](tests/test_state.gd) | การทดสอบ · สคริปต์ GDScript · test_state.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_state.gd) |
| [tests/test_state.gd.uid](tests/test_state.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_state.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_state.gd.uid) |
| [tests/test_tile_preview.gd](tests/test_tile_preview.gd) | การทดสอบ · สคริปต์ GDScript · test_tile_preview.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_tile_preview.gd) |
| [tests/test_tile_preview.gd.uid](tests/test_tile_preview.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_tile_preview.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_tile_preview.gd.uid) |
| [tests/test_transport_game.gd](tests/test_transport_game.gd) | การทดสอบ · สคริปต์ GDScript · test_transport_game.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_transport_game.gd) |
| [tests/test_transport_game.gd.uid](tests/test_transport_game.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_transport_game.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_transport_game.gd.uid) |
| [tests/test_transport_session.gd](tests/test_transport_session.gd) | การทดสอบ · สคริปต์ GDScript · test_transport_session.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_transport_session.gd) |
| [tests/test_transport_session.gd.uid](tests/test_transport_session.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_transport_session.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_transport_session.gd.uid) |
| [tests/test_turn.gd](tests/test_turn.gd) | การทดสอบ · สคริปต์ GDScript · test_turn.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_turn.gd) |
| [tests/test_turn.gd.uid](tests/test_turn.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_turn.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_turn.gd.uid) |
| [tests/test_turn_history.gd](tests/test_turn_history.gd) | การทดสอบ · สคริปต์ GDScript · test_turn_history.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_turn_history.gd) |
| [tests/test_turn_history.gd.uid](tests/test_turn_history.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_turn_history.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_turn_history.gd.uid) |
| [tests/test_turn_result_inspection.gd](tests/test_turn_result_inspection.gd) | การทดสอบ · สคริปต์ GDScript · test_turn_result_inspection.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_turn_result_inspection.gd) |
| [tests/test_turn_result_inspection.gd.uid](tests/test_turn_result_inspection.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_turn_result_inspection.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_turn_result_inspection.gd.uid) |
| [tests/test_turn_results.gd](tests/test_turn_results.gd) | การทดสอบ · สคริปต์ GDScript · test_turn_results.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_turn_results.gd) |
| [tests/test_turn_results.gd.uid](tests/test_turn_results.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_turn_results.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_turn_results.gd.uid) |
| [tests/test_undo.gd](tests/test_undo.gd) | การทดสอบ · สคริปต์ GDScript · test_undo.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_undo.gd) |
| [tests/test_undo.gd.uid](tests/test_undo.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_undo.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_undo.gd.uid) |
| [tests/test_village_advisor.gd](tests/test_village_advisor.gd) | การทดสอบ · สคริปต์ GDScript · test_village_advisor.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_village_advisor.gd) |
| [tests/test_village_advisor.gd.uid](tests/test_village_advisor.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_village_advisor.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_village_advisor.gd.uid) |
| [tests/test_village_life.gd](tests/test_village_life.gd) | การทดสอบ · สคริปต์ GDScript · test_village_life.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_village_life.gd) |
| [tests/test_village_life.gd.uid](tests/test_village_life.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_village_life.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_village_life.gd.uid) |
| [tests/test_village_world.gd](tests/test_village_world.gd) | การทดสอบ · สคริปต์ GDScript · test_village_world.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_village_world.gd) |
| [tests/test_village_world.gd.uid](tests/test_village_world.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_village_world.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_village_world.gd.uid) |
| [tests/test_water.gd](tests/test_water.gd) | การทดสอบ · สคริปต์ GDScript · test_water.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_water.gd) |
| [tests/test_water.gd.uid](tests/test_water.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_water.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_water.gd.uid) |
| [tests/test_water_flow.gd](tests/test_water_flow.gd) | การทดสอบ · สคริปต์ GDScript · test_water_flow.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_water_flow.gd) |
| [tests/test_water_flow.gd.uid](tests/test_water_flow.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_water_flow.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_water_flow.gd.uid) |
| [tests/test_year_expansion.gd](tests/test_year_expansion.gd) | การทดสอบ · สคริปต์ GDScript · test_year_expansion.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_year_expansion.gd) |
| [tests/test_year_expansion.gd.uid](tests/test_year_expansion.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_year_expansion.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_year_expansion.gd.uid) |
| [tests/test_year_game.gd](tests/test_year_game.gd) | การทดสอบ · สคริปต์ GDScript · test_year_game.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_year_game.gd) |
| [tests/test_year_game.gd.uid](tests/test_year_game.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_year_game.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_year_game.gd.uid) |
| [tests/test_year_session.gd](tests/test_year_session.gd) | การทดสอบ · สคริปต์ GDScript · test_year_session.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_year_session.gd) |
| [tests/test_year_session.gd.uid](tests/test_year_session.gd.uid) | การทดสอบ · รหัสอ้างอิงทรัพยากร Godot · test_year_session.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tests/test_year_session.gd.uid) |

### `tools/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [tools/area_development_fixtures.gd](tools/area_development_fixtures.gd) | สคริปต์ GDScript · area_development_fixtures.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/area_development_fixtures.gd) |
| [tools/area_development_fixtures.gd.uid](tools/area_development_fixtures.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · area_development_fixtures.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/area_development_fixtures.gd.uid) |
| [tools/area_development_probe.gd](tools/area_development_probe.gd) | สคริปต์ GDScript · area_development_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/area_development_probe.gd) |
| [tools/area_development_probe.gd.uid](tools/area_development_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · area_development_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/area_development_probe.gd.uid) |
| [tools/balance_scenarios.gd](tools/balance_scenarios.gd) | สคริปต์ GDScript · balance_scenarios.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/balance_scenarios.gd) |
| [tools/balance_scenarios.gd.uid](tools/balance_scenarios.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · balance_scenarios.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/balance_scenarios.gd.uid) |
| [tools/bot_farmer.gd](tools/bot_farmer.gd) | สคริปต์ GDScript · bot_farmer.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/bot_farmer.gd) |
| [tools/bot_farmer.gd.uid](tools/bot_farmer.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · bot_farmer.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/bot_farmer.gd.uid) |
| [tools/bot_greedy.gd](tools/bot_greedy.gd) | สคริปต์ GDScript · bot_greedy.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/bot_greedy.gd) |
| [tools/bot_greedy.gd.uid](tools/bot_greedy.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · bot_greedy.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/bot_greedy.gd.uid) |
| [tools/bot_sim.gd](tools/bot_sim.gd) | สคริปต์ GDScript · bot_sim.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/bot_sim.gd) |
| [tools/bot_sim.gd.uid](tools/bot_sim.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · bot_sim.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/bot_sim.gd.uid) |
| [tools/bracing_probe.gd](tools/bracing_probe.gd) | สคริปต์ GDScript · bracing_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/bracing_probe.gd) |
| [tools/bracing_probe.gd.uid](tools/bracing_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · bracing_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/bracing_probe.gd.uid) |
| [tools/building_detail_probe.gd](tools/building_detail_probe.gd) | สคริปต์ GDScript · building_detail_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/building_detail_probe.gd) |
| [tools/building_detail_probe.gd.uid](tools/building_detail_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · building_detail_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/building_detail_probe.gd.uid) |
| [tools/continue_summary_probe.gd](tools/continue_summary_probe.gd) | สคริปต์ GDScript · continue_summary_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/continue_summary_probe.gd) |
| [tools/continue_summary_probe.gd.uid](tools/continue_summary_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · continue_summary_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/continue_summary_probe.gd.uid) |
| [tools/daily_production_probe.gd](tools/daily_production_probe.gd) | สคริปต์ GDScript · daily_production_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/daily_production_probe.gd) |
| [tools/daily_production_probe.gd.uid](tools/daily_production_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · daily_production_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/daily_production_probe.gd.uid) |
| [tools/end_turn_fixtures.gd](tools/end_turn_fixtures.gd) | สคริปต์ GDScript · end_turn_fixtures.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/end_turn_fixtures.gd) |
| [tools/end_turn_fixtures.gd.uid](tools/end_turn_fixtures.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · end_turn_fixtures.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/end_turn_fixtures.gd.uid) |
| [tools/end_turn_probe.gd](tools/end_turn_probe.gd) | สคริปต์ GDScript · end_turn_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/end_turn_probe.gd) |
| [tools/end_turn_probe.gd.uid](tools/end_turn_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · end_turn_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/end_turn_probe.gd.uid) |
| [tools/food_plan_probe.gd](tools/food_plan_probe.gd) | สคริปต์ GDScript · food_plan_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/food_plan_probe.gd) |
| [tools/food_plan_probe.gd.uid](tools/food_plan_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · food_plan_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/food_plan_probe.gd.uid) |
| [tools/irrigation_fixtures.gd](tools/irrigation_fixtures.gd) | สคริปต์ GDScript · irrigation_fixtures.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/irrigation_fixtures.gd) |
| [tools/irrigation_fixtures.gd.uid](tools/irrigation_fixtures.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · irrigation_fixtures.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/irrigation_fixtures.gd.uid) |
| [tools/irrigation_probe.gd](tools/irrigation_probe.gd) | สคริปต์ GDScript · irrigation_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/irrigation_probe.gd) |
| [tools/irrigation_probe.gd.uid](tools/irrigation_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · irrigation_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/irrigation_probe.gd.uid) |
| [tools/living_village_probe.gd](tools/living_village_probe.gd) | สคริปต์ GDScript · living_village_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/living_village_probe.gd) |
| [tools/living_village_probe.gd.uid](tools/living_village_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · living_village_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/living_village_probe.gd.uid) |
| [tools/long_run_probe.gd](tools/long_run_probe.gd) | สคริปต์ GDScript · long_run_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/long_run_probe.gd) |
| [tools/long_run_probe.gd.uid](tools/long_run_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · long_run_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/long_run_probe.gd.uid) |
| [tools/menu_draft_probe.gd](tools/menu_draft_probe.gd) | สคริปต์ GDScript · menu_draft_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/menu_draft_probe.gd) |
| [tools/menu_draft_probe.gd.uid](tools/menu_draft_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · menu_draft_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/menu_draft_probe.gd.uid) |
| [tools/moisture_probe.gd](tools/moisture_probe.gd) | สคริปต์ GDScript · moisture_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/moisture_probe.gd) |
| [tools/moisture_probe.gd.uid](tools/moisture_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · moisture_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/moisture_probe.gd.uid) |
| [tools/resource_feedback_probe.gd](tools/resource_feedback_probe.gd) | สคริปต์ GDScript · resource_feedback_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/resource_feedback_probe.gd) |
| [tools/resource_feedback_probe.gd.uid](tools/resource_feedback_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · resource_feedback_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/resource_feedback_probe.gd.uid) |
| [tools/resource_ledger_probe.gd](tools/resource_ledger_probe.gd) | สคริปต์ GDScript · resource_ledger_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/resource_ledger_probe.gd) |
| [tools/resource_ledger_probe.gd.uid](tools/resource_ledger_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · resource_ledger_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/resource_ledger_probe.gd.uid) |
| [tools/river_school_probe.gd](tools/river_school_probe.gd) | สคริปต์ GDScript · river_school_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/river_school_probe.gd) |
| [tools/river_school_probe.gd.uid](tools/river_school_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · river_school_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/river_school_probe.gd.uid) |
| [tools/transport_probe.gd](tools/transport_probe.gd) | สคริปต์ GDScript · transport_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/transport_probe.gd) |
| [tools/transport_probe.gd.uid](tools/transport_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · transport_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/transport_probe.gd.uid) |
| [tools/turn_result_inspection_probe.gd](tools/turn_result_inspection_probe.gd) | สคริปต์ GDScript · turn_result_inspection_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/turn_result_inspection_probe.gd) |
| [tools/turn_result_inspection_probe.gd.uid](tools/turn_result_inspection_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · turn_result_inspection_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/turn_result_inspection_probe.gd.uid) |
| [tools/village_world_fixture.gd](tools/village_world_fixture.gd) | สคริปต์ GDScript · village_world_fixture.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/village_world_fixture.gd) |
| [tools/village_world_fixture.gd.uid](tools/village_world_fixture.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · village_world_fixture.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/village_world_fixture.gd.uid) |
| [tools/village_world_probe.gd](tools/village_world_probe.gd) | สคริปต์ GDScript · village_world_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/village_world_probe.gd) |
| [tools/village_world_probe.gd.uid](tools/village_world_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · village_world_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/village_world_probe.gd.uid) |
| [tools/year_probe.gd](tools/year_probe.gd) | สคริปต์ GDScript · year_probe.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/year_probe.gd) |
| [tools/year_probe.gd.uid](tools/year_probe.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_probe.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/year_probe.gd.uid) |
| [tools/year_project_strategy.gd](tools/year_project_strategy.gd) | สคริปต์ GDScript · year_project_strategy.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/year_project_strategy.gd) |
| [tools/year_project_strategy.gd.uid](tools/year_project_strategy.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_project_strategy.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/year_project_strategy.gd.uid) |
| [tools/year_strategy.gd](tools/year_strategy.gd) | สคริปต์ GDScript · year_strategy.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/year_strategy.gd) |
| [tools/year_strategy.gd.uid](tools/year_strategy.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_strategy.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/year_strategy.gd.uid) |

### `tools/scenarios/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [tools/scenarios/m3_food_probe.json](tools/scenarios/m3_food_probe.json) | ข้อมูล JSON · m3_food_probe.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/scenarios/m3_food_probe.json) |
| [tools/scenarios/m3_screen.json](tools/scenarios/m3_screen.json) | ข้อมูล JSON · m3_screen.json | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/tools/scenarios/m3_screen.json) |

### `translations/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [translations/strings.csv](translations/strings.csv) | ข้อมูลตาราง CSV · strings.csv | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/translations/strings.csv) |
| [translations/strings.csv.import](translations/strings.csv.import) | การตั้งค่านำเข้าทรัพยากร Godot · strings.csv.import | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/translations/strings.csv.import) |
| [translations/strings.en.translation](translations/strings.en.translation) | ไฟล์ตั้งค่า/ทรัพยากร · strings.en.translation | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/translations/strings.en.translation) |
| [translations/strings.th.translation](translations/strings.th.translation) | ไฟล์ตั้งค่า/ทรัพยากร · strings.th.translation | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/translations/strings.th.translation) |

### `ui/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [ui/area_development_panel.gd](ui/area_development_panel.gd) | สคริปต์ GDScript · area_development_panel.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/area_development_panel.gd) |
| [ui/area_development_panel.gd.uid](ui/area_development_panel.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · area_development_panel.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/area_development_panel.gd.uid) |
| [ui/boot.gd](ui/boot.gd) | สคริปต์ GDScript · boot.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/boot.gd) |
| [ui/boot.gd.uid](ui/boot.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · boot.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/boot.gd.uid) |
| [ui/boot.tscn](ui/boot.tscn) | ฉาก Godot · boot.tscn | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/boot.tscn) |
| [ui/daily_screen.gd](ui/daily_screen.gd) | สคริปต์ GDScript · daily_screen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/daily_screen.gd) |
| [ui/daily_screen.gd.uid](ui/daily_screen.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · daily_screen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/daily_screen.gd.uid) |
| [ui/difficulty_info.gd](ui/difficulty_info.gd) | สคริปต์ GDScript · difficulty_info.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/difficulty_info.gd) |
| [ui/difficulty_info.gd.uid](ui/difficulty_info.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · difficulty_info.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/difficulty_info.gd.uid) |
| [ui/food_plan_panel.gd](ui/food_plan_panel.gd) | สคริปต์ GDScript · food_plan_panel.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/food_plan_panel.gd) |
| [ui/food_plan_panel.gd.uid](ui/food_plan_panel.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · food_plan_panel.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/food_plan_panel.gd.uid) |
| [ui/game_preferences.gd](ui/game_preferences.gd) | สคริปต์ GDScript · game_preferences.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/game_preferences.gd) |
| [ui/game_preferences.gd.uid](ui/game_preferences.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · game_preferences.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/game_preferences.gd.uid) |
| [ui/game_screen.gd](ui/game_screen.gd) | สคริปต์ GDScript · game_screen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/game_screen.gd) |
| [ui/game_screen.gd.uid](ui/game_screen.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · game_screen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/game_screen.gd.uid) |
| [ui/localization.gd](ui/localization.gd) | สคริปต์ GDScript · localization.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/localization.gd) |
| [ui/localization.gd.uid](ui/localization.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · localization.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/localization.gd.uid) |
| [ui/main_menu.gd](ui/main_menu.gd) | สคริปต์ GDScript · main_menu.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/main_menu.gd) |
| [ui/main_menu.gd.uid](ui/main_menu.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · main_menu.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/main_menu.gd.uid) |
| [ui/resource_feedback.gd](ui/resource_feedback.gd) | สคริปต์ GDScript · resource_feedback.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/resource_feedback.gd) |
| [ui/resource_feedback.gd.uid](ui/resource_feedback.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · resource_feedback.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/resource_feedback.gd.uid) |
| [ui/resource_ledger_panel.gd](ui/resource_ledger_panel.gd) | สคริปต์ GDScript · resource_ledger_panel.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/resource_ledger_panel.gd) |
| [ui/resource_ledger_panel.gd.uid](ui/resource_ledger_panel.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · resource_ledger_panel.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/resource_ledger_panel.gd.uid) |
| [ui/river_school_screen.gd](ui/river_school_screen.gd) | สคริปต์ GDScript · river_school_screen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/river_school_screen.gd) |
| [ui/river_school_screen.gd.uid](ui/river_school_screen.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · river_school_screen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/river_school_screen.gd.uid) |
| [ui/sandbox_screen.gd](ui/sandbox_screen.gd) | สคริปต์ GDScript · sandbox_screen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/sandbox_screen.gd) |
| [ui/sandbox_screen.gd.uid](ui/sandbox_screen.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · sandbox_screen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/sandbox_screen.gd.uid) |
| [ui/theme_builder.gd](ui/theme_builder.gd) | สคริปต์ GDScript · theme_builder.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/theme_builder.gd) |
| [ui/theme_builder.gd.uid](ui/theme_builder.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · theme_builder.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/theme_builder.gd.uid) |
| [ui/transport_panel.gd](ui/transport_panel.gd) | สคริปต์ GDScript · transport_panel.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/transport_panel.gd) |
| [ui/transport_panel.gd.uid](ui/transport_panel.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · transport_panel.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/transport_panel.gd.uid) |
| [ui/transport_screen.gd](ui/transport_screen.gd) | สคริปต์ GDScript · transport_screen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/transport_screen.gd) |
| [ui/transport_screen.gd.uid](ui/transport_screen.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · transport_screen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/transport_screen.gd.uid) |
| [ui/turn_result_locations.gd](ui/turn_result_locations.gd) | สคริปต์ GDScript · turn_result_locations.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/turn_result_locations.gd) |
| [ui/turn_result_locations.gd.uid](ui/turn_result_locations.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · turn_result_locations.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/turn_result_locations.gd.uid) |
| [ui/village_advisor.gd](ui/village_advisor.gd) | สคริปต์ GDScript · village_advisor.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/village_advisor.gd) |
| [ui/village_advisor.gd.uid](ui/village_advisor.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · village_advisor.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/village_advisor.gd.uid) |
| [ui/year_screen.gd](ui/year_screen.gd) | สคริปต์ GDScript · year_screen.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/year_screen.gd) |
| [ui/year_screen.gd.uid](ui/year_screen.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_screen.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/ui/year_screen.gd.uid) |

### `view/`

| ไฟล์ | คำอธิบายย่อ | เนื้อหาโดยตรง |
|---|---|---|
| [view/action_feedback.gd](view/action_feedback.gd) | สคริปต์ GDScript · action_feedback.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/action_feedback.gd) |
| [view/action_feedback.gd.uid](view/action_feedback.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · action_feedback.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/action_feedback.gd.uid) |
| [view/board_view.gd](view/board_view.gd) | สคริปต์ GDScript · board_view.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/board_view.gd) |
| [view/board_view.gd.uid](view/board_view.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · board_view.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/board_view.gd.uid) |
| [view/camera_rig.gd](view/camera_rig.gd) | สคริปต์ GDScript · camera_rig.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/camera_rig.gd) |
| [view/camera_rig.gd.uid](view/camera_rig.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · camera_rig.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/camera_rig.gd.uid) |
| [view/delta_atmosphere.gd](view/delta_atmosphere.gd) | สคริปต์ GDScript · delta_atmosphere.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/delta_atmosphere.gd) |
| [view/delta_atmosphere.gd.uid](view/delta_atmosphere.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · delta_atmosphere.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/delta_atmosphere.gd.uid) |
| [view/flow_view.gd](view/flow_view.gd) | สคริปต์ GDScript · flow_view.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/flow_view.gd) |
| [view/flow_view.gd.uid](view/flow_view.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · flow_view.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/flow_view.gd.uid) |
| [view/lagoon_floor.gdshader](view/lagoon_floor.gdshader) | Shader Godot · lagoon_floor.gdshader | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/lagoon_floor.gdshader) |
| [view/lagoon_floor.gdshader.uid](view/lagoon_floor.gdshader.uid) | รหัสอ้างอิงทรัพยากร Godot · lagoon_floor.gdshader.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/lagoon_floor.gdshader.uid) |
| [view/menu_artwork.gd](view/menu_artwork.gd) | สคริปต์ GDScript · menu_artwork.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/menu_artwork.gd) |
| [view/menu_artwork.gd.uid](view/menu_artwork.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · menu_artwork.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/menu_artwork.gd.uid) |
| [view/menu_landscape.gd](view/menu_landscape.gd) | สคริปต์ GDScript · menu_landscape.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/menu_landscape.gd) |
| [view/menu_landscape.gd.uid](view/menu_landscape.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · menu_landscape.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/menu_landscape.gd.uid) |
| [view/mesh_lib.gd](view/mesh_lib.gd) | สคริปต์ GDScript · mesh_lib.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/mesh_lib.gd) |
| [view/mesh_lib.gd.uid](view/mesh_lib.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · mesh_lib.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/mesh_lib.gd.uid) |
| [view/route_graph.gd](view/route_graph.gd) | สคริปต์ GDScript · route_graph.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/route_graph.gd) |
| [view/route_graph.gd.uid](view/route_graph.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · route_graph.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/route_graph.gd.uid) |
| [view/route_network_view.gd](view/route_network_view.gd) | สคริปต์ GDScript · route_network_view.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/route_network_view.gd) |
| [view/route_network_view.gd.uid](view/route_network_view.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · route_network_view.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/route_network_view.gd.uid) |
| [view/transport_board.gd](view/transport_board.gd) | สคริปต์ GDScript · transport_board.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/transport_board.gd) |
| [view/transport_board.gd.uid](view/transport_board.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · transport_board.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/transport_board.gd.uid) |
| [view/village_life_view.gd](view/village_life_view.gd) | สคริปต์ GDScript · village_life_view.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_life_view.gd) |
| [view/village_life_view.gd.uid](view/village_life_view.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · village_life_view.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_life_view.gd.uid) |
| [view/village_prop_meshes.gd](view/village_prop_meshes.gd) | สคริปต์ GDScript · village_prop_meshes.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_prop_meshes.gd) |
| [view/village_prop_meshes.gd.uid](view/village_prop_meshes.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · village_prop_meshes.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_prop_meshes.gd.uid) |
| [view/village_scene_plan.gd](view/village_scene_plan.gd) | สคริปต์ GDScript · village_scene_plan.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_scene_plan.gd) |
| [view/village_scene_plan.gd.uid](view/village_scene_plan.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · village_scene_plan.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_scene_plan.gd.uid) |
| [view/village_scenery.gd](view/village_scenery.gd) | สคริปต์ GDScript · village_scenery.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_scenery.gd) |
| [view/village_scenery.gd.uid](view/village_scenery.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · village_scenery.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_scenery.gd.uid) |
| [view/village_worker.gd](view/village_worker.gd) | สคริปต์ GDScript · village_worker.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_worker.gd) |
| [view/village_worker.gd.uid](view/village_worker.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · village_worker.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/village_worker.gd.uid) |
| [view/water_surface.gdshader](view/water_surface.gdshader) | Shader Godot · water_surface.gdshader | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/water_surface.gdshader) |
| [view/water_surface.gdshader.uid](view/water_surface.gdshader.uid) | รหัสอ้างอิงทรัพยากร Godot · water_surface.gdshader.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/water_surface.gdshader.uid) |
| [view/year_board.gd](view/year_board.gd) | สคริปต์ GDScript · year_board.gd | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/year_board.gd) |
| [view/year_board.gd.uid](view/year_board.gd.uid) | รหัสอ้างอิงทรัพยากร Godot · year_board.gd.uid | [Raw](https://raw.githubusercontent.com/Warissakorn/Monsoon-Delta/main/view/year_board.gd.uid) |
<!-- project-file-index:end -->
