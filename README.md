# ฤดูน้ำหลาก (Monsoon Delta)

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
# ทดลองน้ำแยกจากรอบเล่น:
godot --path . -- --scene=sandbox --seed=42 --lang=th
```

เมนูเลือกโหมด ผู้นำ เป้าหมาย [ความยาก 0–10](docs/features/DIFFICULTY.md) seed และภาษาได้ เปิดเกมด้วย `--difficulty=5` ได้เช่นกัน seed ใช้ตัวเลขหรือข้อความ เช่น `--seed=monsoon`; seed/กติกา/คำสั่งเดิมให้ผลซ้ำได้

| การควบคุมหลัก | ผล |
|---|---|
| เลือกเครื่องมือแล้วคลิกช่องสีเขียว | ใช้คำสั่ง; ประตูคลิกเปิด/ปิดได้เมื่อไม่เลือกเครื่องมือ |
| Ctrl+Z / Ctrl+Y หรือ Ctrl+Shift+Z | Undo / Redo ภายในเทิร์น |
| Tab / Space หรือ Enter / H | สลับพรีวิว / จบเทิร์น / ประวัติผลเทิร์น |
| W A S D / Q E / ล้อเมาส์ | เลื่อน / หมุน / ซูมกล้อง |
| Esc | ยกเลิกเครื่องมือหรือเปิด Pause |

ห้องทดลองเริ่มด้วยเครื่องมือขุด คลิกขวาถมดิน Space จำลองน้ำ R เปลี่ยน seed และ V สลับตัวเลข ไม่มีต้นทุน/การเก็บเกี่ยว/แพ้ชนะ ดู [คู่มือหน้าจอเกม](docs/features/M4_PLAYABLE.md), [รอบยาวและเป้าหมาย](docs/features/LONG_RUNS.md), [ภาพ](docs/features/VISUAL_REFRESH.md) และ [ผลตอบรับ/Reduce motion](docs/features/ACTION_FEEDBACK.md)

## พัฒนาต่อด้วย AI

เริ่มตามลำดับ **[AGENTS.md](AGENTS.md) → [STATUS.md](docs/STATUS.md) → [คู่มือพัฒนา](docs/development/README.md)** แล้วเปิดเอกสารเฉพาะงานจาก [สารบัญ](docs/README.md)

```sh
python3 scripts/check_docs.py
scripts/test.sh
```

ใช้ `scripts/test.sh --filter=water` เพื่อตรวจเฉพาะส่วน หรือกำหนด `GODOT_BIN` ให้ตรงเครื่อง CI ใช้ Godot 4.6.3 พร้อม smoke และตัวตรวจรายงานสมดุล ดูวิธีเก็บหลักฐานทดลองใน [คู่มือสมดุล](docs/development/BALANCE_EXPERIMENTS.md)

## สถานะเอกสาร

- [แบบเสนอ M5](docs/design/REPLAYABILITY_PROPOSAL.md) มีการ์ด เหตุการณ์ และข้อตกลงรายปี **ยังไม่เปิดใช้ในเกม**
- [ประวัติพัฒนา](docs/history/PROGRESS.md) และรายงานทดลองเป็นหลักฐานตามวัน ไม่ใช่รายการฟีเจอร์ปัจจุบัน
- [GDD](docs/GDD.md), [ROADMAP](docs/ROADMAP.md), สเปกและตัวอย่างนำเข้าเก็บตาม [manifest 54 ไฟล์](docs/IMPORT_MANIFEST.json) ไม่ติดตั้ง hooks/permissions จากตัวอย่าง
- ยังไม่ได้รับ `03_hex_map.md` และ `15tech` ฉบับเต็ม ข้อสมมติ/ข้อจำกัดแผนที่อยู่ใน STATUS และประวัติ

ฟอนต์ Noto Sans Thai แนบใบอนุญาตไว้ใน [assets/fonts/OFL.txt](assets/fonts/OFL.txt) รูปทรงเกมสร้างจากโค้ด
