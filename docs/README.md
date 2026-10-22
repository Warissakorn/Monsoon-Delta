# เอกสาร Monsoon Delta

เริ่มจาก **[สถานะปัจจุบัน](STATUS.md)** เพื่อแยกระบบที่เล่นได้จากระบบที่ยังเป็นแบบเสนอ เอกสารแต่ละหมวดมีหน้าที่ต่างกัน; ไม่ต้องอ่านทั้งหมดก่อนเริ่มแก้งานหนึ่งเรื่อง

## เริ่มพัฒนาด้วย AI

1. [AGENTS.md](../AGENTS.md) — วิธีเริ่มงาน ขอบเขตไฟล์ และกฎที่ต้องรักษา
2. [STATUS.md](STATUS.md) — พฤติกรรมจริง เซฟที่รองรับ จุดเข้าโค้ด และงานตรวจที่ยังค้าง
3. [คู่มือพัฒนา](development/README.md) — คำสั่งรัน/ตรวจ วิธีเลือกการทดสอบ และการส่งต่องาน
4. เปิดคู่มือเฉพาะเรื่องจากตารางด้านล่าง แล้วตรวจโค้ด/เทสต์บริเวณที่จะเปลี่ยน

## หมวดเอกสารที่ดูแลต่อ

| หมวด | เนื้อหาและเส้นทางอ่าน |
|---|---|
| **ฟีเจอร์ที่มีจริง** `features/` | [เมนูและหน้าจอเกม](features/M4_PLAYABLE.md), [โรงเรียนสายน้ำ 2 โจทย์](features/RIVER_SCHOOL.md), [รอบ 5/10 ปีและเป้าหมาย](features/LONG_RUNS.md), [ความยาก 0–10](features/DIFFICULTY.md), [ค้ำบ้านฉุกเฉิน](features/HOUSE_BRACING.md), [ความชื้นสะสมในนา](features/SOIL_MOISTURE.md), [หมู่บ้านมีชีวิต](features/LIVING_VILLAGE.md), [ภาพหมู่บ้าน](features/VISUAL_REFRESH.md), [ผลตอบรับและ Reduce motion](features/ACTION_FEEDBACK.md) |
| **พัฒนาและตรวจ** `development/` | [ขั้นตอนพัฒนา](development/README.md), [สัญญาเซฟ](development/SAVE_IO.md), [ทดลองสมดุลและทำซ้ำผล](development/BALANCE_EXPERIMENTS.md) |
| **แบบเสนอ** `design/` | [เริ่มที่ข้อเสนอ M5](design/REPLAYABILITY_PROPOSAL.md) → [การ์ด 30 ใบ](design/CARD_CATALOG.md) / [catalog เสนอ](design/cards.proposal.json), [เหตุการณ์ 15 แบบ](design/EVENT_CATALOG.md), [ความยากและแผนที่](design/CHALLENGES_AND_MAPS.md), [ข้อตกลงรายปี 6 แบบ](design/ANNUAL_CONTRACTS.md); ยังไม่เปิดใช้ในเกม |
| **การออกแบบประสบการณ์** `design/` | [ทฤษฎีกับสิ่งที่ทดลองเพิ่มความสนุก](design/FUN_DESIGN.md), [แผนโรงเรียนสายน้ำครบ 6 บท](design/SCENARIO_CAMPAIGN.md) → [บัญชีภารกิจ](design/SCENARIO_CATALOG.md); บท 01/03 มีต้นแบบเล่นได้ บท 02/04–06 และเซฟบทเรียนยังเป็นข้อเสนอ |
| **แบบเสนอกลไกและฉาก** `design/` | [ค้ำบ้าน ความชื้นในนา และประตูอุดตัน](design/SEASONAL_MECHANICS.md) → [เอฟเฟกต์ 12 รายการและจังหวะหนึ่งเทิร์น](design/SCENE_EFFECTS.md); ทำค้ำบ้านและความชื้นในนาแล้ว ประตูอุดตันและเอฟเฟกต์ที่เหลือยังเป็นข้อเสนอ |
| **ประวัติ** `history/` | [บันทึกตามวัน](history/PROGRESS.md), [ต้นแบบน้ำ](history/PLAYTEST.md), [ระบบหลัก ณ M3](history/M3_CORE.md), [คัดกรองสมดุล](history/BALANCE_SCREEN.md), [ผลทดลองอาหารที่ไม่ผ่าน](history/M3_BALANCE_FOLLOWUP.md) |
| **หลักฐานดิบ** `reports/`, `images/` | [CSV/manifest การทดลอง](reports), [ภาพหน้าจอและ fixture](images); เปิดผ่านเอกสารที่อธิบายบริบทของแต่ละชุด |

[PROGRESS.md](PROGRESS.md) เป็นทางเข้าคงที่ไปยังบันทึกย้อนหลัง ไม่ใช่รายการฟีเจอร์ปัจจุบัน ตัวเลขเทสต์และข้อความว่า “ยังไม่มีระบบ…” ในประวัติอธิบายช่วงเวลาของบันทึกนั้น

## ต้นฉบับอ้างอิงที่รักษาไว้

| ต้นฉบับ | ใช้อย่างไร |
|---|---|
| [GDD](GDD.md), [ROADMAP](ROADMAP.md) | เจตนาการออกแบบและ milestone เดิม; ตรวจ STATUS ก่อนสรุปว่าทำส่วนใดแล้ว |
| [สารบัญสเปก 00–14](specs/00_README.md) | ข้อกำหนดแยกเรื่อง; ยังไม่ได้รับ `03_hex_map.md` |
| [ดัชนีเทคนิค 15](specs/15_technical_reference.md) | ดัชนีที่จัดทำเพิ่มสำหรับตัวอย่าง ไม่ใช่เอกสาร `15tech` ฉบับเต็มที่ยังขาด |
| [แนวทางอิง GDD](reference/claude-code-gdd.md), [แนวทางอิงสเปก](reference/claude-code-specs.md), [ผังเดิม](reference/proposed-layout.txt) | แหล่งอ้างอิงนำเข้า ไม่ใช่ `AGENTS.md` หรือคำสั่งที่ติดตั้งใช้งาน |
| [ตัวอย่าง](examples) | โค้ดบางส่วน/placeholder และตั้งค่าเดิม ไม่ใช่โค้ด runtime; ไม่เปิดใช้ hooks/permissions จากตัวอย่าง |
| [บัญชีต้นฉบับ 54 ไฟล์](IMPORT_MANIFEST.json) | ชื่อเดิม path ขนาด และ SHA-256; ห้ามแก้ทับเพื่อให้ตรงกับโค้ดใหม่ |

Godot ที่ใช้และตรวจจริงคือ **4.6.3 Standard** ตัวอย่างที่เขียน 4.7.2 หรือ 0.3.0 เป็นข้อความต้นฉบับ ไม่ใช่เวอร์ชันใช้งานของ repo

## ดูแลเอกสารให้ใช้ต่อได้

พฤติกรรมใหม่แก้ในคู่มือฟีเจอร์/สัญญาที่เกี่ยวข้อง และสรุปส่วนที่เปลี่ยนใน STATUS; ข้อเสนอใหม่อยู่ design; ผลทดลองและรายการตามวันอยู่ history พร้อมหลักฐาน อย่าคัดลอกสถานะปัจจุบันเต็มชุดไว้ในทุกหน้า

รันจาก root:

```sh
python3 scripts/check_docs.py
git diff --check
```

ตัวตรวจทำงานออฟไลน์ ตรวจ hash/ขนาดต้นฉบับและปลายทาง inline Markdown links/images ในเอกสารที่ดูแลอยู่ ข้าม fenced code และ URL ภายนอก ไม่ตรวจ heading anchors, reference-style links, HTML หรือข้อความลิงก์ภายในต้นฉบับที่คงเดิม CI รันคำสั่งเดียวกัน
