# 06 ลำดับเกม

## API ของ GameFlow (UI เรียกแค่ชุดนี้) [T-01]
```gdscript
static func new_game(cfg: Dictionary) -> GameState
#   cfg = {seed:int, map_type:String, leader:String, difficulty:int, is_daily:bool, is_tutorial:bool}
static func pick_card(s: GameState, index: int) -> bool
static func choose_event(s: GameState, choice: int) -> bool
static func apply_command(s: GameState, cmd: Command) -> String   # check + push undo + apply; คืน "" หรือ error key
static func undo(s: GameState) -> GameState                       # คืน state ที่ย้อนแล้ว (UI ต้องเปลี่ยนไปใช้ตัวนี้)
static func preview(s: GameState) -> Dictionary                   # {state: GameState, report: TurnReport} ไม่แตะ s
static func end_turn(s: GameState) -> TurnReport
static func continue_after_harvest(s: GameState) -> void
```
- UndoStack ผูกกับ state ผ่านฟิลด์ที่ไม่บันทึก `s.undo`

## [T-02] new_game
1. MapGen ตาม cfg.seed และ map_type
2. ตั้ง leader, difficulty, cards = [], recompute_mods()
3. population = start_population, food = start_food, wood = start_food... (ดูบรรทัดถัดไป)
   - ใช้ค่าจริงดังนี้: population = mod.start_population, food = mod.start_food, wood = mod.start_wood (แต่ละค่าไม่ต่ำกว่า 0)
4. rng.seed = derive_seed(seed, 1)
5. year = 1, turn = 1, stats เริ่มต้น (max_population = population, reached_year = 1)
6. start_year

## [T-03] start_year
**ลำดับการใช้ rng ต้องเป็นตามนี้เท่านั้น:** เสนอการ์ด → สุ่มว่าเกิดเหตุการณ์ไหม → เลือกเหตุการณ์ → สุ่มภายในผลเหตุการณ์ → พยากรณ์

1. ทุก SAPLING → FOREST (ปี 1 ไม่มี SAPLING อยู่แล้ว)
2. ทุก PADDY: paddy_yield = 0, paddy_dead = false, paddy_rain_turns = 0
3. year_mods = [] แล้ว recompute_mods()
4. food += year_start_food, wood += year_start_wood
5. stats.reached_year = year
6. เสนอการ์ด:
   - pool = id การ์ดทั้งหมดที่ยังไม่มี เรียงตามตัวอักษร
   - k = min(card_offer_count, pool.size())
   - สุ่ม k ใบโดยไม่ซ้ำ (randi_range ทีละครั้งแล้วลบออกจาก pool)
   - ถ้า k > 0 → phase CARD_PICK และรอ pick_card ไม่งั้นไปข้อ 7 เลย
7. หลังเลือกการ์ด (หรือข้ามขั้นเสนอการ์ด):
   - ถ้า year ≥ 2 และ rng.randf() < event_chance → สุ่มเหตุการณ์จากรายการที่เข้าเงื่อนไข (08) แล้วไป phase EVENT
   - ถ้าไม่เกิด ไปข้อ 8
8. พยากรณ์ [T-05] → begin_turn [T-07]

## [T-04] pick_card / choose_event
- **pick_card:** ตรวจ phase และ index → cards.append → card_offer = [] → recompute_mods() → ไปข้อ 7 ของ T-03
- **choose_event:** ตรวจ phase และว่า choice ใช้ได้ → ทำผล (08) → pending_event = "" → ไปข้อ 8 ของ T-03

## [T-05] พยากรณ์
```text
(bmin, bmax) = rain_table[year]          # จาก balance.json
mult = rain_inflow_multiplier × (year5_inflow_multiplier ถ้า year == 5 ไม่งั้น 1)
mn = bmin × mult; mx = bmax × mult
mid = (mn + mx) / 2; half = (mx − mn) / 2 × forecast_range_multiplier
mn = mid − half; mx = mid + half
total = rng.randf_range(mn, mx)
w = [rng.randf_range(0.25, 0.45) สามครั้ง]
rain_inflows[i] = total × w[i] / Σw
rain_inflows[2] += storm_last_turn_add
forecast_min = mn + storm_last_turn_add
forecast_max = mx + storm_last_turn_add
```

## [T-06] น้ำเข้าของเทิร์น
- ฤดูแล้ง: dry_inflow
- ฤดูฝน: rain_inflows[turn − 4]
- การเปิดเผย: น้ำเข้าฤดูฝนของเทิร์นใดผู้เล่นเห็นได้ตั้งแต่ begin_turn ของเทิร์นนั้น หรือเห็นทั้ง 3 ค่าตั้งแต่ต้นปีถ้า reveal_all_inflow = 1

## [T-07] begin_turn
1. phase = PLANNING
2. labor = population + (season_first_turn_labor ถ้า turn เป็น 1 หรือ 4) + (rain_turn_labor ถ้าเป็นฤดูฝน)
3. labor_max = labor
4. ล้าง undo แล้วบันทึกเกม

## [T-08] resolve_turn (TurnResolver.resolve_turn(s, record_snapshots) -> TurnReport)
ห้ามใช้ rng ใน resolve_turn

1. levels_before = level ของทุกช่อง
2. WaterSim.simulate(s, current_inflow, record_snapshots)
3. absorbed = WaterSim.absorb(s)
4. ถ้าฤดูแล้ง: evaporated = WaterSim.evaporate(s)
5. **ความเสียหาย** วนช่องตามลำดับ index ใช้ L = level หลังข้อ 4

   | สิ่งก่อสร้าง | พังเมื่อ L ≥ |
   |---|---|
   | HOUSE | house_destroy_level |
   | STILT_HOUSE | stilt_destroy_level |
   | GRANARY | granary_destroy_level |
   | อื่น ๆ (RAFT, GATE, FISH_TRAP, RESERVOIR, WATERWHEEL) | ไม่พัง |

   - พัง → building = NONE แล้วบันทึกลง report.destroyed (ถ้าเป็นบ้าน 3 ชนิด stats.houses_lost += 1 แต่ RAFT ไม่มีวันพังอยู่แล้ว)
   - HALL: L ≥ 1 → stats.hall_ever_wet = true; L ≥ hall_lose_level → outcome = LOSE_HALL
   - PADDY ที่ยังไม่ตาย และ L ≥ paddy_death_level → paddy_dead = true, paddy_yield = 0, stats.paddies_lost += 1, บันทึกลง report
6. ถ้า outcome ≠ NONE → คืน report (ข้ามการผลิต)
7. **การผลิต** (ตามลำดับ index):
   - **ฤดูฝน:** นาที่ยังไม่ตาย และ paddy_min_level ≤ L ≤ paddy_max_level → paddy_yield += 1, paddy_rain_turns += 1
   - **ฤดูแล้ง (นาปรัง):** นาที่ยังไม่ตาย และมีเพื่อนบ้านเป็น RESERVOIR ที่ water ≥ dry_paddy_reservoir_min
     - เลือกบึงที่มีน้ำมากสุด (ถ้าเท่ากัน ใช้ index ต่ำสุด)
     - paddy_yield += 1 และบึงนั้น water −= dry_paddy_water_use
   - **FISH_TRAP ทุกฤดู:** L ≥ 1 (ใช้ L จากข้อ 5) → food += fish_trap_yield × fish_trap_multiplier
8. stats.food_produced += อาหารจากไซดักปลา
9. levels_after = level ของทุกช่อง และคืน report

## [T-09] TurnReport (ฟิลด์)
inflow, to_sea, from_sea, absorbed, evaporated, destroyed: Array[{coord, building}], paddies_died: Array[Vector2i], paddy_gains: Array[Vector2i], fish_food: int, hall_wet: bool, outcome: int, levels_before / levels_after: PackedInt32Array, snapshots

## [T-10] preview
- c = s.duplicate_state(); report = resolve_turn(c, true); คืน {state: c, report}
- **ต้องเป็นจริง:** ผลของ preview ต้องตรงกับผลจริงของ end_turn ในส่วน resolve ทุกฟิลด์

## [T-11] end_turn
1. assert phase == PLANNING
2. report = resolve_turn(s, true)
3. ถ้า outcome ≠ NONE → จบรอบ [T-14]
4. ถ้า turn == 6 → Harvest.do_harvest(s) → phase HARVEST → บันทึกเกม
5. ถ้าไม่ใช่ ให้ turn += 1 แล้ว begin_turn
6. คืน report

## [T-12] ที่อยู่
- capacity = Σ (home_capacity + home_capacity_bonus) ของ HOUSE, STILT_HOUSE และ RAFT_HOUSE ที่ยังอยู่
- ศาลาไม่นับเป็นที่อยู่

## [T-13] เก็บเกี่ยว (Harvest.do_harvest) ทำตามลำดับ แล้วเก็บทุกตัวเลขไว้ใน harvest_report
1. **ผลผลิตนา** ของแต่ละนาที่ยังไม่ตาย:
   - f = paddy_yield
   - ถ้า f ≥ 1: f += harvest_paddy_bonus; f += jasmine_bonus ถ้า paddy_rain_turns == 3; f += fertile_silt_bonus ถ้าช่องเป็นแม่น้ำหรือติดช่องแม่น้ำ
   - food += f, stats.food_produced += f
2. **กิน:** need = population × food_per_person
   - food ≥ need → food −= need
   - ไม่พอ → left_hunger = ceili((need − food) / food_per_person), population −= left_hunger, food = 0
3. **ที่อยู่:** ถ้า population > capacity → left_housing = population − capacity แล้ว population = capacity
4. **คนเพิ่ม:** born = min(capacity − population, floori(food / food_per_growth)); population += born; food −= born × food_per_growth
5. **อาหารเน่า:** ถ้าไม่มี GRANARY → spoiled = floori(food × clampf(rot_fraction, 0, 1)); food −= spoiled
6. stats.max_population = max(เดิม, population)
7. population == 0 → outcome = LOSE_POPULATION / ถ้าไม่ใช่และ year == 5 → outcome = WIN
- harvest_report = {paddy_food, eaten, left_hunger, left_housing, born, spoiled, food_after, population_after}

## [T-14] จบรอบ
- outcome LOSE_HALL: phase = GAME_OVER ทันทีหลัง end_turn
- outcome จากการเก็บเกี่ยว: แสดงหน้าสรุปปีก่อน แล้ว continue_after_harvest จึงเข้า GAME_OVER
- เมื่อเข้า GAME_OVER: final_score = Scoring.score(s), อัปเดตโปรไฟล์ (09), ลบเซฟ

## [T-15] continue_after_harvest
- outcome ≠ NONE → [T-14]
- ไม่ใช่ → year += 1, turn = 1, start_year