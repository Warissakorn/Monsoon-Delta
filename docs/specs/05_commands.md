# 05 คำสั่งของผู้เล่น

## API [CM-01]
- `CommandRules.check(s, cmd) -> String`: คืน "" ถ้าทำได้ หรือคืน key เหตุผลข้อแรกที่ไม่ผ่าน
- `CommandRules.cost(s, cmd) -> Vector2i`: (แรงงาน, ไม้) ตามฤดูปัจจุบันและ mod
- `CommandRules.apply(s, cmd) -> void`: เรียกได้หลัง check ผ่านแล้วเท่านั้น (assert) หักต้นทุนแล้วเปลี่ยน state
- `CommandRules.valid_targets(s, id, param) -> Array[Vector2i]`: ใช้ไฮไลต์ช่อง
- คำสั่งห้ามใช้ rng

## ลำดับการตรวจ [CM-02]
ตรวจตามลำดับนี้ แล้วคืน key ของข้อแรกที่ไม่ผ่าน

| # | ตรวจ | key |
|---|---|---|
| 1 | phase == PLANNING | err.phase |
| 2 | คำสั่งถูกปลดล็อก (คอลัมน์ "ต้องมี mod") | err.locked |
| 3 | มีช่องนั้นจริง | err.no_tile |
| 4 | ฤดูถูกต้อง | err.season |
| 5 | เป้าหมายถูกต้อง | err.target |
| 6 | เงื่อนไขน้ำ (ใช้ level ปัจจุบัน) | err.water |
| 7 | param ถูกต้อง | err.param |
| 8 | แรงงานพอ | err.labor |
| 9 | ไม้พอ | err.wood |

## ตารางคำสั่ง [CM-10..CM-24]
"ว่าง" = ช่องว่างตามนิยามใน 00 / "ว่าง/นา" = ว่าง หรือมีแค่ feature PADDY

| รหัส | id | ฤดู | เป้าหมาย | น้ำ | แรงงาน (mod) | ไม้ (mod) | ผล |
|---|---|---|---|---|---|---|---|
| CM-10 | dig | ทั้งคู่ | ว่าง/นา, elevation ≥ 1 | ใดก็ได้ | dig_labor_dry หรือ dig_labor_rain (ขั้นต่ำ 1) | 0 | elevation = max(0, e − dig_amount) น้ำในช่องเท่าเดิม |
| CM-11 | fill | ทั้งคู่ | ว่าง/นา, elevation ≤ 3 | ใดก็ได้ | fill_labor_dry หรือ fill_labor_rain (ขั้นต่ำ 1) | 0 | elevation = min(4, e + fill_amount) น้ำในช่องเท่าเดิม |
| CM-12 | paddy | แล้ง | ว่าง | level 0 | paddy_labor | 0 | feature = PADDY, yield 0, ยังไม่ตาย |
| CM-13 | house | ทั้งคู่ | ว่าง | level 0 | house_labor | house_wood | building = HOUSE |
| CM-14 | stilt_house | ทั้งคู่ | ว่าง | level 0 | stilt_labor | stilt_wood | building = STILT_HOUSE |
| CM-15 | raft_house (ต้องมี unlock_raft_house) | ทั้งคู่ | ไม่มีสิ่งก่อสร้าง, feature NONE, ไม่ใช่ทะเลหรือต้นน้ำ | level ≥ 1 | raft_labor | raft_wood | building = RAFT_HOUSE |
| CM-16 | chop | ทั้งคู่ | feature FOREST | ใดก็ได้ | chop_labor | 0 | feature = NONE, ไม้ += chop_wood |
| CM-17 | plant | แล้ง | ว่าง | level 0 | plant_labor | 0 | feature = SAPLING |
| CM-18 | gate | ทั้งคู่ | ว่าง | ใดก็ได้ | gate_labor | gate_wood | building = GATE, gate_open = true |
| CM-19 | toggle_gate | ทั้งคู่ | building GATE | ใดก็ได้ | 0 | 0 | gate_open = not gate_open |
| CM-20 | reservoir | แล้ง | ว่าง | level 0 | reservoir_labor | 0 | elevation = max(−3, e − reservoir_depth), building = RESERVOIR |
| CM-21 | fish_trap | ทั้งคู่ | ว่าง | ใดก็ได้ | fish_trap_labor | fish_trap_wood | building = FISH_TRAP |
| CM-22 | granary | ทั้งคู่ | ว่าง | level 0 | granary_labor | granary_wood | building = GRANARY |
| CM-23 | waterwheel (ต้องมี unlock_waterwheel) | ทั้งคู่ | ว่าง | ใดก็ได้ | wheel_labor | wheel_wood | building = WATERWHEEL, wheel_dir = param |
| CM-24 | demolish | ทั้งคู่ | มี building ที่ไม่ใช่ HALL, หรือ feature PADDY/SAPLING | ใดก็ได้ | demolish_labor | 0 | ดู [CM-30] |

- CM-23: param ต้องเป็น 0..5 และเพื่อนบ้านทิศนั้นต้องมีอยู่และไม่ใช่ทะเล ถ้าไม่ผ่านคืน err.param
- คำสั่งอื่น param ต้องเป็น −1

## [CM-30] การรื้อถอน
- มี building: คืนไม้ = floori(ต้นทุนไม้ปัจจุบันของสิ่งนั้น × demolish_refund_fraction) แล้วตั้ง building = NONE, gate_open = true, wheel_dir = −1
  - RESERVOIR: elevation คงเดิม (ไม่ถมกลับ)
- feature PADDY หรือ SAPLING: feature = NONE, รีเซ็ตค่า paddy_* ทั้งหมด และไม่คืนอะไร

## [CM-31] ต้นทุนในฤดูฝน
- dig/fill ใช้คีย์ *_rain ซึ่งค่าเริ่มต้นเป็น 4 ส่วนคำสั่งอื่นใช้ต้นทุนเท่าเดิมทั้งปี

## [CM-32] แรงงาน
- labor ลดลงตามต้นทุน ห้ามติดลบ (ป้องกันไว้แล้วด้วย check)
- ไม่ต้องจ่ายต้นทุนซ้ำเมื่อ undo