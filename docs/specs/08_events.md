# 08 เหตุการณ์สุ่ม (data/events.json)

## [E-01] รูปแบบ
{"id": "...", "requires": {...}, "choices": [{"requires": {...}, "effects": [...]}, ...]}
- ข้อความ: event.<id>.title / event.<id>.desc / event.<id>.choice<n> (n เริ่มที่ 0)
- เหตุการณ์ที่มีตัวเลือกเดียว ปุ่มใช้ key ui.ok
- ทุกเหตุการณ์ต้องมีอย่างน้อย 1 ตัวเลือกที่ไม่มี requires

## [E-02] เงื่อนไข (requires)
| key | ความหมาย |
|---|---|
| min_food / min_wood / min_population | ทรัพยากรต้อง ≥ ค่านี้ |
| min_forests | จำนวนช่อง FOREST ≥ ค่านี้ |
| no_granary | ต้องไม่มี GRANARY |
| needs_riverbank | ต้องมีช่องตลิ่งตาม [E-04] อย่างน้อย 1 ช่อง |

- **เหตุการณ์ที่เข้าเงื่อนไข:** requires ของเหตุการณ์ผ่าน
- **การสุ่ม:** เรียงตาม id แล้ว randi_range
- **ตัวเลือกที่ requires ไม่ผ่าน:** แสดงแต่กดไม่ได้

## [E-03] ผล (effects)
| type | ฟิลด์ | ผล |
|---|---|---|
| resource | key (food/wood/population), amount | บวกค่า (ไม่ต่ำกว่า 0) ถ้า population เปลี่ยน ให้ update stats.max_population |
| year_mod | key, op, value | เพิ่มเข้า year_mods แล้ว recompute_mods() |
| lose_food_fraction | fraction | food −= floori(food × fraction) |
| remove_forests | count | สุ่ม FOREST ทีละช่อง (ไม่ซ้ำ) จำนวน min(count, ที่มี) แล้วตั้งเป็น NONE |
| lower_riverbank | count | สุ่มช่องตลิ่ง [E-04] แล้ว elevation −1 |

## [E-04] ช่องตลิ่ง
ไม่ใช่แม่น้ำ/ต้นน้ำ/ทะเล, ไม่มี building, feature เป็น NONE หรือ PADDY, ติดช่องแม่น้ำ และ elevation ≥ 1

## [E-05] รายการ 15 เหตุการณ์
| # | id | ไทย | requires | ตัวเลือกและผล |
|---|---|---|---|---|
| 1 | merchant_boat | พ่อค้าเรือ | - | 0: (min_wood 3) wood −3, food +4 / 1: (min_food 4) food −4, wood +3 / 2: ไม่แลก |
| 2 | fish_run | ปลาชุม | - | 0: year_mod fish_trap_multiplier set 2 |
| 3 | long_drought | แล้งยาว | - | 0: year_mod rain_inflow_multiplier mul 0.7; year_mod evaporation_multiplier set 2 |
| 4 | storm | พายุเข้า | - | 0: year_mod storm_last_turn_add add 4 |
| 5 | refugees | ผู้อพยพ | - | 0: population +2 / 1: ปฏิเสธ |
| 6 | rats | หนูนา | no_granary, min_food 1 | 0: lose_food_fraction 0.25 |
| 7 | wildfire | ไฟป่า | min_forests 1 | 0: remove_forests 2 |
| 8 | fair_weather | ฟ้าฝนเป็นใจ | - | 0: year_mod forecast_range_multiplier mul 0.5 |
| 9 | wandering_carpenter | ช่างไม้พเนจร | - | 0: year_mod house_wood add −1; stilt_wood add −1; raft_wood add −1 |
| 10 | good_seed | พันธุ์ข้าวดี | - | 0: year_mod harvest_paddy_bonus add 1 |
| 11 | fever | ไข้ป่า | min_population 2 | 0: (min_food 3) food −3 / 1: population −1 |
| 12 | log_raft | แพซุงลอยมา | - | 0: wood +3 |
| 13 | early_rain | ฝนมาก่อนฤดู | - | 0: year_mod dry_inflow set 1.5 |
| 14 | village_fair | งานรื่นเริงหมู่บ้าน | - | 0: (min_food 2) food −2; year_mod season_first_turn_labor add 2 / 1: ไม่จัด |
| 15 | bank_collapse | ตลิ่งพัง | needs_riverbank | 0: lower_riverbank 1 |