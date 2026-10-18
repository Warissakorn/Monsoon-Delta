# ทดลองสมดุลแบบทำซ้ำได้

เครื่องมือ M3 ใช้ทดลองค่าในหน่วยความจำของ process เท่านั้น ไม่เขียน balance.json หรือเซฟเกม และไม่เปลี่ยน policy ของบอท ค่าเริ่มต้นของเกมยังเหมือนเดิม งานนี้ช่วยทำการทดลองต่อจาก [การคัดกรองสมดุล](../history/BALANCE_SCREEN.md); ยังไม่ถือว่าผ่าน TS-06

## เริ่มทดลอง

หลัง import โปรเจกต์หรือรัน scripts/test.sh:

```sh
godot --headless --path . --script res://tools/bot_sim.gd -- \
  --scenarios=res://tools/scenarios/m3_screen.json \
  --bot=all --runs=20 --seed-start=1 --candidates=8 \
  --output=res://bot_reports --revision=screen-round-1
```

ตัวอย่างมี baseline และ C3 จากรายงานเดิม C3 เป็นชุดคัดกรองที่ยังไม่ผ่านเป้า greedy จึงไม่ใช่ค่าที่เสนอใช้จริง ใช้ --runs=200 เมื่อต้องการยืนยันผล; จำนวนเกมน้อยใช้สำรวจเท่านั้น difficulty 10 ต้องรันแยกด้วย --difficulty=10

คำสั่งเดิมที่ไม่มี --scenarios ยังใช้ได้ โดยรัน scenario ชื่อ baseline หนึ่งชุด --map=all หมายถึง plains เท่านั้นตามขอบเขต M3 บอททุกตัวใช้ผู้นำ farmer และ greedy คงวิธีเลือกคำสั่งเดิม

แต่ละครั้งสร้างโฟลเดอร์ใหม่ bot_reports/run_<เวลา UTC>_<รหัส process timer>/ และพิมพ์ตำแหน่งเต็ม ไม่เขียนทับรายงานเดิม ภายในมี:

- manifest.json: สถานะ running/complete/failed, seed ต้น–ท้ายเป็นข้อความเพื่อเก็บ int64 ครบ, Godot, Git revision/dirty ถ้ามี, label จาก --revision, SHA-256 ของ balance/scenario, ค่าตั้งบอททั้งหมด, overrides และ effective modifiers หลัง map → leader → difficulty
- summary.csv: อัตราชนะ ปีเฉลี่ย สาเหตุแพ้ ประชากร คะแนน เวลา จำนวนเกมที่ทำเสร็จ และ error ต่อ scenario/บอท
- <scenario>/<bot>_plains_d<difficulty>.csv: ผลรายเกมในคอลัมน์เดิม รวม seed ผลจบ ปี ประชากร คะแนน จำนวนเทิร์น/คำสั่ง และเวลา

--revision เป็นป้ายกำกับเพิ่มเติม ไม่แทน Git SHA ที่ตรวจได้เอง หากไม่มี Git หรือเป็น source export ข้อมูล Git จะว่าง เวลาเป็นเวลาของเครื่องที่รัน ไม่ใช้เป็นการรับประกันความเร็วของเครื่องอื่น

## รูปแบบไฟล์

```json
{
  "version": 1,
  "scenarios": [
    {
      "id": "baseline",
      "mods": {}
    },
    {
      "id": "rain_timing",
      "mods": {
        "rain_inflow_multiplier": 1.1,
        "year5_inflow_multiplier": 1.2
      }
    }
  ]
}
```

version ต้องเป็น 1 และ scenarios ต้องมีอย่างน้อยหนึ่งรายการ id ใช้ตัวอักษรอังกฤษ/เลขเริ่มต้น ตามด้วยตัวอักษร เลข _ หรือ - รวมไม่เกิน 64 ตัว ต้องไม่ซ้ำกันแม้ต่างตัวพิมพ์ใหญ่/เล็ก และห้ามชื่อสงวนของ Windows เช่น CON/NUL/COM1 mods ใช้เฉพาะ key ใน mods_default ของ data/balance.json; ไม่รองรับการแก้ rain_table, map_generation หรือ weights ของบอทผ่านไฟล์นี้

ตรวจทั้งไฟล์ก่อนสร้างโฟลเดอร์หรือเริ่มเกม หากรายการหลังผิด รายการก่อนจะไม่เริ่มรัน ไม่ยอมรับ key ที่สะกดผิด boolean ข้อความ NaN/Infinity หรือทศนิยมในต้นทุน/ทรัพยากรที่ต้องเป็นจำนวนเต็ม ค่า override เป็นค่าแทนที่ของ base default ก่อนใช้ modifier ของแผนที่ ผู้นำ และความยาก ไม่ใช่ modifier ที่บวกหลังสุด

ขอบเขตทดลอง: ค่าสัมบูรณ์ไม่เกิน 1,000,000; flow_rate 0.05–0.9; สัดส่วนเน่า/คืนไม้และ event_chance 0–1; flags เป็น 0/1; water_iterations 1–1,000; ตัวหารอาหาร ความจุ ประชากรตั้งต้น จำนวนการ์ดและปริมาณขุด/ถม/ขุดบึงต้องมากกว่า 0 ต้นทุนและผลผลิตทั่วไปห้ามติดลบ ค่าทะเลต้องไม่ติดลบเพราะใช้เป็นปริมาณน้ำโดยตรง อนุญาต bonus บางตัวติดลบ เช่น harvest_paddy_bonus=-2 เพื่อทำซ้ำการคัดกรองเดิม ระดับน้ำที่ทำลายสิ่งก่อสร้างใช้ค่า 4 ขึ้นไปเพื่อให้ไม่ถึงได้ตามกฎเดิม

เริ่มทุก scenario จากสำเนา default เดิมและคืนค่าหลังรัน รวมถึงกรณีจำลองหรือเขียนรายงานล้มเหลว รายงานที่ล้มเหลวมีสถานะ failed และ completed ใช้บอกจำนวนที่ทำสำเร็จ ห้ามใช้รายงาน running/failed เป็น benchmark ครบชุด หาก filesystem ปฏิเสธการเขียน manifest เอง อาจไม่มีสถานะสุดท้ายให้อ่าน ให้ใช้ exit code และข้อความผิดพลาดด้วย

## ข้อจำกัดในการเทียบผล

seed เดียวกันใช้ RNG/คำสั่งแบบเดิมภายในชุดค่าเดียวกัน แต่ค่าเกี่ยวกับน้ำมีผลต่อการคัดแผนที่ที่ปลอดภัยใน MapGen ด้วย จึงอาจได้ภูมิประเทศต่างกันเมื่อเปลี่ยน scenario การเทียบเป็น seed ชุดเดียวกัน ไม่รับประกันว่าเป็นกระดานเดิม ผลเวลาอาจต่างกันได้แม้ผลเกมเหมือนกัน

เป้า TS-06 ยังต้องตรวจ farmer difficulty 0 ชนะไม่เกิน 5% และปีเฉลี่ยอย่างน้อย 3, greedy difficulty 0 ชนะ 20–60%, greedy difficulty 10 ชนะไม่เกิน 10%, และเวลา 200 เกม ก่อนเสนอเปลี่ยนค่าเริ่มต้น

## ตรวจเครื่องมือ

```sh
scripts/test.sh --filter=balance_scenarios
python3 scripts/test_balance_cli.py
```

Python ใช้ stdlib และ executable จาก GODOT_BIN (ค่าเริ่มต้น godot) ทดสอบ CLI จริง: baseline ตรงกับการรันปกติ, baseline → เปลี่ยนค่า → baseline ไม่รั่วข้ามชุด, ลำดับ modifier, สรุปตรง CSV, input ผิดไม่สร้างรายงาน และ filesystem error คืน exit code ไม่เป็นศูนย์ ไฟล์ทดลองใช้ temporary directory

## ตรวจเกณฑ์ตัวเลข TS-06

หลังรัน farmer difficulty 0, greedy difficulty 0 และ greedy difficulty 10 ด้วยชุดค่าเดียวกันอย่างน้อยกรณีละ 200 เกม ใช้ `scripts/check_balance.py` ตรวจ manifest ทั้งสามไฟล์:

```sh
python3 scripts/check_balance.py path/to/farmer/manifest.json path/to/greedy-d0/manifest.json path/to/greedy-d10/manifest.json --scenario=your_scenario
python3 scripts/test_check_balance.py
```

ถ้าไม่ระบุ `--scenario` จะตรวจทุก scenario ในรายงาน โปรแกรมอ่าน CSV รายเกมมาคำนวณจำนวนชนะ สาเหตุแพ้ ปี ประชากร และคะแนนใหม่ ตรวจ seed ครบไม่ซ้ำ ผลจบสอดคล้องกับปี/จำนวนเทิร์น และเทียบกับยอดใน manifest ทุกไฟล์ต้องมาจาก Git revision ที่สะอาดเดียวกัน ใช้รุ่น Godot และ seed ชุดเดียวกัน balance hash, base mods, bot configuration และ overrides ตรงกัน

- exit 0: ผ่านเกณฑ์ตัวเลขของ plains ครบทั้งสามกรณี
- exit 1: มีข้อมูลครบ แต่มีเกณฑ์ที่วัดแล้วไม่ผ่าน
- exit 2: ไฟล์ผิด ข้อมูลไม่สอดคล้อง แหล่งโค้ด/ค่าตั้งไม่ตรง จำนวนเกมต่ำกว่า 200 หรือยังขาดกรณีที่ต้องตรวจ

ตัวตรวจไม่รวมหลายรายงานสั้นให้กลายเป็น benchmark 200 เกม แต่ละ batch ต้องมีอย่างน้อย 200 เกมด้วยตัวเอง แสดงเวลาทั้ง batch และเวลาต่อ 200 เกม (`seconds × 200 / runs`) เพื่อเทียบเป้า 300 วินาที ถ้ารันเกิน 200 เกม ค่าต่อ 200 เป็นอัตราที่คำนวณจาก batch นั้น ไม่ใช่เวลาที่จับแยกอีกครั้ง

ย้ายรายงานได้โดยเก็บ `manifest.json` กับโฟลเดอร์ `<scenario>/<bot>_plains_d<difficulty>.csv` ไว้ด้วยกัน ตัวตรวจให้ไฟล์ที่อยู่ข้าง manifest มีลำดับก่อน path เดิมที่บันทึกไว้ จึงตรวจสำเนาที่เผยแพร่จริง แม้ไฟล์ต้นทางยังอยู่บนเครื่อง

ผลผ่านยืนยันเฉพาะเกณฑ์ตัวเลขที่มีใน plains ไม่แทนการตรวจโดยผู้เล่น ความสนุกของการบังคับน้ำ หรือแผนที่ valley/estuary ที่ยังไม่เปิดใช้งาน ดู [ผลทดลองอาหารและความยาก](../history/M3_BALANCE_FOLLOWUP.md)
