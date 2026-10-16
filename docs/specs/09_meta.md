# 09 คะแนน โปรไฟล์ ปลดล็อก และท้าทายรายวัน

## [MT-01] คะแนน
- base = population × 10 + food
- ถ้า outcome == WIN: +50 ถ้า houses_lost == 0, +30 ถ้า hall_ever_wet == false
- final = roundi(base × (1 + 0.1 × difficulty))
- ถ้าแพ้ คิดแค่ base (ไม่มีโบนัส) แล้วคูณความยากเหมือนกัน

## [MT-02] โปรไฟล์ (user://profile.json)
{"format": "monsoon_profile", "version": 1,
 "maps_unlocked": ["plains"], "leaders_unlocked": ["farmer"],
 "highest_difficulty_unlocked": 0,
 "wins": {"plains": 0, "valley": 0, "estuary": 0},
 "best_score": {"plains": 0, "valley": 0, "estuary": 0},
 "daily": {"20250101": 0}, "runs_played": 0, "tutorial_done": false}
- โหลดไม่ได้ → สร้างใหม่ด้วยค่าเริ่มต้น (ห้าม crash)

## [MT-03] อัปเดตตอนจบรอบ
- รอบบทสอนเล่น: ตั้ง tutorial_done = true แล้วจบ (ไม่ทำข้ออื่น)
- รอบท้าทายรายวัน: daily[date] = max(เดิม, final_score) แล้วจบ (ไม่ปลดล็อกอะไร)
- รอบปกติ:
  - runs_played += 1 และ best_score[map] = max(เดิม, final_score)
  - ถ้าชนะ: wins[map] += 1 และ highest_difficulty_unlocked = min(10, max(เดิม, difficulty + 1))
  - ปลดล็อก (เพิ่มเข้า list ถ้ายังไม่มี และให้ UI แสดงข้อความปลดล็อก):

| ปลดล็อก | เงื่อนไข |
|---|---|
| map valley | ชนะ (แผนที่ใดก็ได้) |
| map estuary | ชนะบน valley |
| leader carpenter | stats.reached_year ≥ 3 |
| leader fisher | stats.max_population ≥ 15 |
| leader soil_doctor | ชนะ และ houses_lost == 0 |

## [MT-04] ท้าทายรายวัน
- วันที่ local (ui/ อ่านจาก Time แล้วส่งเข้า core) → seed = int("YYYYMMDD")
- map = ["plains", "valley", "estuary"][seed % 3]
- leader = ["farmer", "carpenter", "fisher", "soil_doctor"][(seed / 3) % 4]
- difficulty = 2
- ไม่ต้องสนใจการปลดล็อก และเล่นซ้ำได้ โดยเก็บคะแนนที่ดีที่สุดไว้

## [MT-05] seed ของรอบใหม่
- ช่อง seed ว่าง → ui/ สุ่มด้วย randi() % 1000000000
- พิมพ์มา → SeedUtil.parse_seed_text
- แสดง seed ในเมนูหยุดเกมและหน้าจบเกม