# ฤดูน้ำหลาก (Monsoon Delta)

เกมวางแผนเทิร์นเบสแนว roguelite: บังคับทางน้ำบนแผนที่ hex ให้หมู่บ้านรอดฤดูน้ำหลาก 5 ปี

- สเปกเกม (แหล่งความจริงเดียว): @docs/GDD.md
- ความคืบหน้าและการตัดสินใจล่าสุด: @docs/PROGRESS.md
- แผนงานทีละขั้น: docs/ROADMAP.md

## Tech
- Godot 4 (stable ล่าสุด), GDScript เท่านั้น, ระบุ type ทุกตัวแปร พารามิเตอร์ และค่าที่คืน
- คำสั่งเรียก Godot บนเครื่องนี้: `godot`
  - ถ้าไม่ตรง ให้แก้เป็น path จริง เช่น macOS `/Applications/Godot.app/Contents/MacOS/Godot`
  - Windows ให้ใช้ไฟล์ที่ลงท้าย `_console.exe` เพื่อให้เห็น output ใน terminal
- ห้ามติดตั้ง addon หรือไลบรารีภายนอกโดยไม่ถามก่อน
- โค้ด ชื่อตัวแปร คอมเมนต์ และ commit message เป็นภาษาอังกฤษ

## สถาปัตยกรรม (ห้ามละเมิด)
- `core/` = ตรรกะเกมล้วน extends RefCounted เท่านั้น ห้ามอ้าง Node, SceneTree, Input, เวลา หรือ randf()/randi() แบบ global
- สุ่มทุกอย่างผ่าน RandomNumberGenerator ที่เก็บ seed และ state ไว้ใน GameState: seed เดียวกันต้องได้ผลเหมือนกันทุกครั้ง
- GameState ต้องมี `duplicate_state()` (deep copy) และ `to_dict()` / `from_dict()` สำหรับ preview, undo และ save
- ผู้เล่นเปลี่ยน state ได้ทางเดียวคือผ่าน Command (`can_apply(state) -> bool` และ `apply(state)`)
- `view/` และ `ui/` แค่อ่าน state มาแสดง แล้วส่ง Command กลับ ห้ามแก้ state ตรง ๆ
- ตัวเลขสมดุลทั้งหมดอยู่ใน `data/*.json` ห้าม hardcode
- ภาพทั้งหมดสร้างจากโค้ด (primitive mesh + shader) ไม่มีไฟล์โมเดล 3D
- ประกอบ scene ด้วยโค้ดเป็นหลัก ใช้ไฟล์ .tscn ให้น้อยและเรียบง่าย
- ข้อความที่ผู้เล่นเห็นต้องผ่าน `tr()` ทุกตัว (ไทย/อังกฤษ)

## โฟลเดอร์
core/ view/ ui/ data/ shaders/ tests/ tools/ translations/ assets/fonts/ assets/audio/ docs/ screenshots/

## คำสั่งตรวจงาน (รันเองได้เลย)
- เทสต์: `godot --headless --path . --script res://tests/run_tests.gd` (exit code ไม่เป็น 0 = มีเทสต์ไม่ผ่าน)
- บอทปรับสมดุล: `godot --headless --path . --script res://tools/bot_sim.gd -- --runs=200`
- ภาพหน้าจอ: `godot --path . -- --screenshot=screenshots/latest.png` แล้วเปิดไฟล์ภาพดูเอง
  (screenshots/ มีไฟล์ .gdignore และอยู่ใน .gitignore)

## วิธีทำงาน
- ทำเฉพาะ milestone ที่ถูกสั่ง ถ้าเห็นงานที่ควรทำเพิ่ม ให้จดไว้ใน PROGRESS.md แทน
- แก้อะไรใน core/ ต้องมีเทสต์คู่กัน และรันเทสต์ผ่านทั้งหมดก่อนบอกว่าเสร็จ
- แก้บั๊ก: เขียนเทสต์ที่ fail ให้ได้ก่อน แล้วค่อยแก้
- งานด้านภาพ: ถ่ายภาพหน้าจอตรวจเองก่อนบอกว่าเสร็จ
- สเปกกำกวมหรือขัดกัน: เรื่องใหญ่ให้ถามก่อน เรื่องเล็กตัดสินใจเองได้แต่ต้องบันทึกเหตุผลใน PROGRESS.md
- ผู้ใช้ขอเปลี่ยนดีไซน์: แก้ docs/GDD.md ก่อน แล้วค่อยแก้โค้ดให้ตรง
- ทำเสร็จแต่ละรอบ: อัปเดต PROGRESS.md (ทำอะไรไป ค้างอะไร ตัดสินใจอะไร) แล้ว git commit