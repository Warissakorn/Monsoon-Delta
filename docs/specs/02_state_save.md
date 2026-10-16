# 02 สถานะเกม การบันทึก และ undo

## Tile [S-01]
| ฟิลด์ | type | ค่าเริ่มต้น | หมายเหตุ |
|---|---|---|---|
| q, r | int | - | ห้ามเปลี่ยนหลังสร้าง |
| elevation | int | 0 | −3..4 |
| water | float | 0.0 | ≥ 0 |
| feature | C.Feature | NONE | |
| building | C.Building | NONE | ถ้าไม่ใช่ NONE แล้ว feature ต้องเป็น NONE |
| gate_open | bool | true | ใช้เมื่อเป็น GATE |
| wheel_dir | int | -1 | 0..5 ใช้เมื่อเป็น WATERWHEEL |
| is_source / is_sea / is_river | bool | false | is_river เป็นข้อมูลจากตอนสร้างแผนที่ ไม่เปลี่ยนตามน้ำ |
| paddy_yield | int | 0 | ผลผลิตสะสมของปีนี้ |
| paddy_dead | bool | false | |
| paddy_rain_turns | int | 0 | จำนวนเทิร์นฝนที่ให้ผล (ใช้กับการ์ดข้าวหอมมะลิ) |
| start_house | bool | false | บ้านเริ่มต้น (ใช้ตรวจแผนที่) |

## GameState [S-02]
| ฟิลด์ | type | หมายเหตุ |
|---|---|---|
| version | int | = 1 |
| seed | int | seed ของรอบ |
| map_type | String | "plains" / "valley" / "estuary" |
| leader | String | id ผู้ใหญ่บ้าน |
| difficulty | int | 0..10 |
| is_daily, is_tutorial | bool | |
| tiles | Array[Tile] | เรียงตามลำดับ index ใน 03 [H-03] |
| year | int | 1..5 |
| turn | int | 1..6 |
| phase | C.Phase | |
| population, food, wood, labor, labor_max | int | |
| cards | Array[String] | ตามลำดับที่เลือก |
| card_offer | Array[String] | การ์ดที่เสนอในปีนี้ (ว่างเมื่อเลือกแล้ว) |
| pending_event | String | "" = ไม่มี |
| year_mods | Array[Dictionary] | mod จากเหตุการณ์ของปีนี้ |
| forecast_min, forecast_max | float | ช่วงน้ำเข้ารวมของฤดูฝนที่แสดง |
| rain_inflows | Array[float] | 3 ค่า ซ่อนจากผู้เล่นจนถึงเทิร์นนั้น (เว้นแต่ reveal_all_inflow) |
| rng | RandomNumberGenerator | สุ่มทุกอย่างของเกมผ่านตัวนี้ |
| stats | Dictionary | houses_lost:int, paddies_lost:int, hall_ever_wet:bool, max_population:int, food_produced:int, reached_year:int |
| outcome | C.Outcome | |
| harvest_report | Dictionary | ผลเก็บเกี่ยวล่าสุด (ต้องบันทึก เพื่อแสดงหน้าสรุปซ้ำหลังโหลด) |
| final_score | int | กำหนดตอนจบรอบ |

**ค่าที่คำนวณแล้ว cache (ห้ามบันทึก):** `index: Dictionary` (Vector2i → int) และ `mods: Dictionary`

### เมธอดที่ต้องมี
```gdscript
func get_tile(coord: Vector2i) -> Tile          # null ถ้าไม่มี
func neighbors(t: Tile) -> Array[Tile]          # ลำดับทิศตาม 03 [H-02], ข้ามช่องที่ไม่มี
func neighbor_in_dir(t: Tile, dir: int) -> Tile # null ถ้าไม่มี
func season() -> int                            # turn <= 3 → DRY
func is_rain() -> bool
func mod(key: String) -> Variant                # อ่านจาก mods cache
func recompute_mods() -> void                   # 07 [M-02]
func current_inflow() -> float                  # 06 [T-06]
func capacity() -> int                          # 06 [T-12]
func has_building(b: int) -> bool
func level_of(t: Tile) -> int                   # 04 [W-02]
func duplicate_state() -> GameState             # deep copy รวม rng state
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> GameState
```

## การแปลงเป็น dict [S-03]
- enum → string ตัวพิมพ์เล็ก (Building.STILT_HOUSE → "stilt_house")
- seed, rng seed และ rng state → **String** (เช่น "18446744073") แล้วอ่านกลับด้วย String.to_int() เพราะ JSON เก็บ int 64 บิตไม่แม่น
- tiles → Array ของ dict ตามลำดับ index ทุกฟิลด์ใน [S-01]
- อ่าน int จาก JSON ต้องครอบด้วย int() เสมอ (JSON parse คืนค่าเป็น float)
- from_dict ต้องเรียก rebuild index และ recompute_mods()
- เงื่อนไข: `from_dict(to_dict(s)).to_dict() == s.to_dict()` ทุกกรณี

## ไฟล์บันทึก [S-04]
- path: user://save.json
- รูปแบบ: {"format": "monsoon_save", "version": 1, "state": {...}}
- **บันทึกเมื่อ:** เข้า phase CARD_PICK, EVENT, HARVEST และตอน begin_turn ทุกครั้ง
- **ลบเมื่อ:** เข้า GAME_OVER
- **โหลดไม่ได้** (format/version ผิด หรือ parse ไม่ได้): ลบไฟล์ แล้วแสดงข้อความ `msg.save_corrupt`
- เขียนแบบปลอดภัย: เขียน save.json.tmp ก่อน แล้ว rename ทับ
- เกมบทสอนเล่นไม่บันทึก

## Undo [S-05]
- UndoStack เก็บ Array ของ dict (to_dict) สูงสุด 200 รายการ (เกินให้ทิ้งตัวเก่าสุด)
- ก่อน apply คำสั่งที่ผ่าน check ทุกครั้ง: push(state.to_dict())
- undo(): pop แล้วแทนที่ state ทั้งก้อนด้วย from_dict
- ล้าง stack เมื่อ: end_turn, เปลี่ยน phase, โหลดเกม
- การเลือกการ์ดและเหตุการณ์ย้อนไม่ได้

## Settings [S-06]
- path: user://settings.json
- ฟิลด์: master, music, sfx, ambience (float 0..1, ค่าเริ่มต้น 0.8/0.6/0.8/0.7), language ("th"/"en"), fullscreen (false)
- ภาษาเริ่มต้น: ถ้า OS.get_locale() ขึ้นต้นด้วย "th" ใช้ "th" นอกนั้นใช้ "en"