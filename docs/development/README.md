# คู่มือพัฒนาและส่งต่องาน

อ่าน [STATUS](../STATUS.md) เพื่อรู้ขอบเขตจริง และใช้ตารางจุดเข้าโค้ดท้ายหน้านั้นเลือกไฟล์ตามงาน คู่มือนี้รวมคำสั่งใช้งาน ส่วนกฎเทิร์น/เซฟที่ต้องรักษาอยู่ใน STATUS และ [สัญญาเซฟ](SAVE_IO.md)

## เปิดและตรวจงาน

ทุกคำสั่งรันจาก root ใช้ **Godot 4.6.3 Standard** ไม่ต้องใช้ .NET; ตั้ง `GODOT_BIN` หาก executable ชื่อต่างจาก `godot`

```sh
# เปิดเมนู / เกมใหม่ (ใช้เซฟแยกสำหรับพัฒนา)
godot --path . -- --scene=menu --lang=th
godot --path . -- --scene=game --seed=42 --lang=en --save-path=user://dev-run.json
godot --path . -- --scene=game --run-mode=long --goal=forest --seed=42 --save-path=user://dev-long.json
# เลือกความยากในกฎเดิม 0–10; รับเฉพาะจำนวนเต็มในช่วงนี้
godot --path . -- --scene=game --difficulty=5 --seed=42 --save-path=user://dev-difficulty.json
# รอบใหม่ที่เปิดค้ำบ้านหนึ่งเทิร์น
godot --path . -- --scene=game --ruleset=bracing_v1 --seed=42 --save-path=user://dev-bracing.json
# ความชื้นสะสมในนา แยกเดี่ยวหรือใช้ร่วมกับค้ำบ้าน
godot --path . -- --scene=game --ruleset=moisture_v1 --seed=42 --save-path=user://dev-moisture.json
godot --path . -- --scene=game --ruleset=bracing_moisture_v1 --seed=42 --save-path=user://dev-seasonal.json
# เลือกโจทย์สั้น / เข้าโจทย์โดยตรง ไม่มี checkpoint บทเรียน
godot --path . -- --scene=school --lang=th
godot --path . -- --scene=school --lesson=river_school_01 --lang=th
# ห้องทดลองน้ำไม่เขียนเซฟรอบเล่น
godot --path . -- --scene=sandbox --seed=42 --lang=th

# ตรวจเอกสาร แล้วตรวจระบบที่เกี่ยวข้อง / ชุดเต็ม
python3 scripts/check_docs.py
scripts/test.sh --filter=save
scripts/test.sh
git diff --check
```

`scripts/test.sh` import โปรเจกต์ก่อนและตรวจ error จาก log แม้ Godot ออกด้วย status 0 ใช้ `--filter=game_screen`, `session`, `water` หรือชื่อส่วนที่เกี่ยวข้องได้ จำนวนเทสต์ฐานและหลักฐานล่าสุดอ้างใน STATUS; อย่าเปลี่ยนจำนวนเทสต์ในรายงานเก่าให้เป็นจำนวนปัจจุบัน

เมื่อแก้ boot/ตัวเลือก CLI รัน `python3 scripts/test_boot_cli.py` และ `python3 scripts/test_school_cli.py` เพิ่มเพื่อตรวจระดับความยาก seed เริ่มต้น และการปฏิเสธค่าผิดก่อนแตะ checkpoint ด้วยการเปิด Godot จริงบนเซฟ/ค่าตั้งแยก

## เลือกการตรวจตามสิ่งที่เปลี่ยน

| การเปลี่ยน | การตรวจที่เหมาะสม |
|---|---|
| Markdown/ย้ายเอกสาร | `check_docs.py` + `git diff --check`; ตรวจว่าไม่เปลี่ยนความหมายของรายงานเก่า |
| กฎ/คำสั่ง/น้ำ/เป้าหมาย | เทสต์ส่วนที่เกี่ยวข้อง แล้วชุด Godot เต็ม; เทียบ preview กับผลจริงและตรวจ state/RNG |
| state/เซฟ | ชุด save/session และทั้งชุด; load→เล่นต่อ, float64/RNG, compatibility, ไฟล์เสีย/เขียนล้มเหลว และ isolated save paths |
| UI/คีย์บอร์ด/ภาพ | เทสต์ที่เกี่ยวข้อง + native window ไทย/อังกฤษ 1280×720; headless ยืนยันหน้าตา/โฟกัสไม่ได้ |
| balance/บอท | แยก config ทดลอง เก็บ CSV+manifest และใช้ [คู่มือสมดุล](BALANCE_EXPERIMENTS.md); smoke ไม่ใช่ benchmark หรือ playtest โดยคน |
| checker เอกสาร | ตรวจ repo จริงและกรณี broken link/ต้นฉบับเปลี่ยนด้วย temporary fixture; ห้ามแก้ไฟล์นำเข้าจริงเพื่อทดสอบ |

[CI](../../.github/workflows/tests.yml) ตรวจเอกสาร Godot tests, smoke เมนู/เกม/sandbox/รอบยาว, บอท, balance CLI และ Python report checker ใช้ผลที่รันกับ commit ที่กำลังส่ง ไม่ใช้ CI เก่ารับรองการเปลี่ยน runtime ใหม่

โรงเรียนสายน้ำใช้ [fixture/replay](../../core/river_school_fixtures.gd), [controller](../../core/river_school_run.gd) และ [หน้าจอเฉพาะ](../../ui/river_school_screen.gd) บนกฎเดิม ใช้ `scripts/test.sh --filter=river_school` ตรวจผลจริง/Retry/RNG/การรักษาเซฟปกติ แล้วตรวจทั้งชุด การผ่านเทสต์ไม่แทนการทดลองความเข้าใจหรือความสนุกกับผู้เล่นตาม [แผนตรวจ](../design/FUN_DESIGN.md)

### ตรวจภาพและการควบคุม

เปิดหน้าต่างที่เรนเดอร์ได้; `--headless` ถ่ายภาพเกมไม่ได้ ตรวจเมาส์ Tab/Shift+Tab/Enter/Space, modal, Undo/Redo, preview, Continue และ Reduce motion ตามส่วนที่เปลี่ยน ภาพจาก fixture ต้องระบุว่าเป็น fixture แยกจากการเล่น seed จริง

```sh
mkdir -p screenshots
godot --path . -- --scene=sandbox --seed=42 --lang=th --screenshot=screenshots/sandbox.png
```

ตรวจการรักษาตัวเลือกเกมใหม่เมื่อเปลี่ยนภาษาด้วย [menu draft probe](../../tools/menu_draft_probe.gd) บนหน้าต่าง 1280×720; probe ตั้งแบบฟอร์ม fixture ไว้ก่อน แล้วใช้เมาส์/คีย์บอร์ดสลับภาษา เปิดเกมใหม่และยกเลิกคำยืนยัน ตรวจว่า Continue คงเดิม ขั้นเริ่มรอบสุดท้ายเรียก controller และสัญญาณยืนยันโดยตรงเพื่อตรวจ config ที่ส่งให้ session ตั้ง XDG แยกเมื่อทดลอง เปลี่ยน `en` เป็น `th` เพื่อตรวจอีกทิศทาง:

```sh
XDG_DATA_HOME="$PWD/work/menu-draft-qa/en/data" XDG_CONFIG_HOME="$PWD/work/menu-draft-qa/en/config" XDG_CACHE_HOME="$PWD/work/menu-draft-qa/en/cache" godot --path . --audio-driver Dummy --resolution 1280x720 --script res://tools/menu_draft_probe.gd -- --out-dir="$PWD/work/menu-draft-qa/en" --lang=en
```

[River School probe](../../tools/river_school_probe.gd) ตรวจการยกเลิกออกจากประวัติและหน้าต่างยืนยันจบเทิร์นด้วย รวมโฟกัส ตำแหน่งเลื่อน ช่องไม่ถามซ้ำ และการกด Enter ที่ต้องยกเลิกออกเพียงครั้งเดียว เพิ่ม `--modal-only` หลัง `--lang` เมื่อต้องการตรวจเฉพาะส่วนนี้; ไม่ใส่ flag จะตรวจ flow โรงเรียนทั้งชุด ดูคำสั่งและบริบท fixture ใน [คู่มือโรงเรียนสายน้ำ](../features/RIVER_SCHOOL.md#ภาพและหลักฐาน)

## วิธีอัปเดตโดยไม่สร้างเอกสารซ้ำ

1. ตรวจ `git status`/branch และอ่านข้อกำหนดเฉพาะเรื่อง ระบุว่ากำลังแก้พฤติกรรมที่มีอยู่หรือทำตามแบบที่ยอมรับแล้ว
2. แก้ runtime และคู่มือเฉพาะเรื่องให้ตรงกัน; ถ้าขอบเขตการใช้งาน/เซฟ/ข้อจำกัดเปลี่ยน ให้แก้ [STATUS](../STATUS.md) ด้วย
3. ข้อเสนอที่ยังไม่ทำเก็บใน `docs/design/` พร้อมสถานะชัดเจน; แก้ปัญหาสเปกนำเข้าด้วยบันทึกความต่าง ห้ามแก้ต้นฉบับใน manifest
4. บันทึกผลที่มีหลักฐานและข้อจำกัดตามวันใน [history/PROGRESS](../history/PROGRESS.md) เพิ่มลิงก์ในสารบัญเมื่อมีเอกสารใหม่ ไม่สร้าง CURRENT/TODO/HANDOFF หลายฉบับที่บอกเรื่องเดียวกัน
5. รันการตรวจตามตาราง สรุปไฟล์หลัก ผลตรวจ และงานค้างใน PR ให้ผู้อื่นเริ่มต่อได้ โดยไม่ต้องอ่านบทสนทนาก่อนหน้า

การส่งต่องานควรระบุ commit/branch, ขอบเขตที่เสร็จ, คำสั่งตรวจและผล, และประเด็นที่ยังไม่ยืนยัน ไม่ใส่ token, credentials หรือข้อมูลจากเซฟจริงลงเอกสาร
