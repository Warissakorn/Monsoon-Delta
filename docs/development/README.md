# คู่มือพัฒนาและส่งต่องาน

อ่าน [STATUS](../STATUS.md) เพื่อรู้ขอบเขตจริง และใช้ตารางจุดเข้าโค้ดท้ายหน้านั้นเลือกไฟล์ตามงาน คู่มือนี้รวมคำสั่งใช้งาน ส่วนกฎเทิร์น/เซฟที่ต้องรักษาอยู่ใน STATUS และ [สัญญาเซฟ](SAVE_IO.md)

## เปิดและตรวจงาน

ทุกคำสั่งรันจาก root ใช้ **Godot 4.6.3 Standard** ไม่ต้องใช้ .NET; ตั้ง `GODOT_BIN` หาก executable ชื่อต่างจาก `godot`

```sh
# เปิดเมนู / เกมใหม่ (ใช้เซฟแยกสำหรับพัฒนา)
godot --path . -- --scene=menu --lang=th
godot --path . -- --scene=game --seed=42 --lang=en --save-path=user://dev-run.json
godot --path . -- --scene=game --run-mode=long --goal=forest --seed=42 --save-path=user://dev-long.json
# ห้องทดลองน้ำไม่เขียนเซฟรอบเล่น
godot --path . -- --scene=sandbox --seed=42 --lang=th

# ตรวจเอกสาร แล้วตรวจระบบที่เกี่ยวข้อง / ชุดเต็ม
python3 scripts/check_docs.py
scripts/test.sh --filter=save
scripts/test.sh
git diff --check
```

`scripts/test.sh` import โปรเจกต์ก่อนและตรวจ error จาก log แม้ Godot ออกด้วย status 0 ใช้ `--filter=game_screen`, `session`, `water` หรือชื่อส่วนที่เกี่ยวข้องได้ จำนวนเทสต์ฐานและหลักฐานล่าสุดอ้างใน STATUS; อย่าเปลี่ยนจำนวนเทสต์ในรายงานเก่าให้เป็นจำนวนปัจจุบัน

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

### ตรวจภาพและการควบคุม

เปิดหน้าต่างที่เรนเดอร์ได้; `--headless` ถ่ายภาพเกมไม่ได้ ตรวจเมาส์ Tab/Shift+Tab/Enter/Space, modal, Undo/Redo, preview, Continue และ Reduce motion ตามส่วนที่เปลี่ยน ภาพจาก fixture ต้องระบุว่าเป็น fixture แยกจากการเล่น seed จริง

```sh
mkdir -p screenshots
godot --path . -- --scene=sandbox --seed=42 --lang=th --screenshot=screenshots/sandbox.png
```

## วิธีอัปเดตโดยไม่สร้างเอกสารซ้ำ

1. ตรวจ `git status`/branch และอ่านข้อกำหนดเฉพาะเรื่อง ระบุว่ากำลังแก้พฤติกรรมที่มีอยู่หรือทำตามแบบที่ยอมรับแล้ว
2. แก้ runtime และคู่มือเฉพาะเรื่องให้ตรงกัน; ถ้าขอบเขตการใช้งาน/เซฟ/ข้อจำกัดเปลี่ยน ให้แก้ [STATUS](../STATUS.md) ด้วย
3. ข้อเสนอที่ยังไม่ทำเก็บใน `docs/design/` พร้อมสถานะชัดเจน; แก้ปัญหาสเปกนำเข้าด้วยบันทึกความต่าง ห้ามแก้ต้นฉบับใน manifest
4. บันทึกผลที่มีหลักฐานและข้อจำกัดตามวันใน [history/PROGRESS](../history/PROGRESS.md) เพิ่มลิงก์ในสารบัญเมื่อมีเอกสารใหม่ ไม่สร้าง CURRENT/TODO/HANDOFF หลายฉบับที่บอกเรื่องเดียวกัน
5. รันการตรวจตามตาราง สรุปไฟล์หลัก ผลตรวจ และงานค้างใน PR ให้ผู้อื่นเริ่มต่อได้ โดยไม่ต้องอ่านบทสนทนาก่อนหน้า

การส่งต่องานควรระบุ commit/branch, ขอบเขตที่เสร็จ, คำสั่งตรวจและผล, และประเด็นที่ยังไม่ยืนยัน ไม่ใส่ token, credentials หรือข้อมูลจากเซฟจริงลงเอกสาร
