# 07 Modifier การ์ด ผู้ใหญ่บ้าน แผนที่ และความยาก

## [M-01] รูปแบบ mod
{"key": "house_wood", "op": "add" | "mul" | "set", "value": number}
ค่า boolean ใช้ 0 หรือ 1

## [M-02] การคำนวณ (recompute_mods)
เริ่มจากค่าเริ่มต้นใน balance.json → "mods_default" แล้วใช้ mod ทีละตัวตามลำดับนี้

1. แผนที่ (maps[map_type].mods)
2. ผู้ใหญ่บ้าน
3. ความยากระดับ 1 ถึง difficulty ตามลำดับ
4. การ์ดตามลำดับที่เลือก
5. year_mods

- ถ้า key ไม่อยู่ใน mods_default → push_error และข้าม
- คำสั่ง set จะทับค่าที่คำนวณมาก่อนหน้าทั้งหมด

## [M-03] รายการ mod ทั้งหมด (ค่าเริ่มต้นอยู่ใน balance.json)
| กลุ่ม | key: ค่าเริ่มต้น |
|---|---|
| น้ำ | flow_rate 0.5, water_iterations 20, sea_level_dry 0, sea_level_rain 0, dry_inflow 0.5, forest_absorb 0.3, sapling_absorb 0, evaporation_dry 0.25, evaporation_multiplier 1, wheel_amount 0.5 |
| พยากรณ์ | rain_inflow_multiplier 1, year5_inflow_multiplier 1, forecast_range_multiplier 1, storm_last_turn_add 0, reveal_all_inflow 0 |
| ต้นทุนแรงงาน | dig_labor_dry 2, dig_labor_rain 4, fill_labor_dry 2, fill_labor_rain 4, paddy_labor 1, house_labor 2, stilt_labor 3, raft_labor 2, chop_labor 1, plant_labor 1, gate_labor 3, reservoir_labor 4, fish_trap_labor 1, granary_labor 2, wheel_labor 2, demolish_labor 1 |
| ต้นทุนไม้ | house_wood 2, stilt_wood 3, raft_wood 3, gate_wood 2, fish_trap_wood 1, granary_wood 3, wheel_wood 2 |
| ปริมาณ | dig_amount 1, fill_amount 1, reservoir_depth 3, chop_wood 2, demolish_refund_fraction 0.5 |
| เกณฑ์ | house_destroy_level 1, stilt_destroy_level 2, granary_destroy_level 2, hall_lose_level 2, paddy_death_level 2, paddy_min_level 1, paddy_max_level 1 |
| ผลผลิต | fish_trap_yield 1, fish_trap_multiplier 1, harvest_paddy_bonus 0, jasmine_bonus 0, fertile_silt_bonus 0, dry_paddy_reservoir_min 0.5, dry_paddy_water_use 0.25 |
| ประชากร | food_per_person 1, food_per_growth 2, rot_fraction 0.5, home_capacity 2, home_capacity_bonus 0 |
| แรงงานโบนัส | season_first_turn_labor 0, rain_turn_labor 0 |
| เริ่มเกม/รายปี | start_population 6, start_food 6, start_wood 2, year_start_food 0, year_start_wood 0 |
| ปลดล็อก | unlock_waterwheel 0, unlock_raft_house 0 |
| อื่น ๆ | card_offer_count 3, event_chance 0.5 |

**การอ่านค่า:** mod ที่เป็นจำนวนนับ (level, ต้นทุน, amount, yield, count) ให้อ่านด้วย roundi(); mod อื่นอ่านเป็น float; ค่า level ที่ ≥ 4 หมายถึงไม่มีวันถึง

## [M-04] ผู้ใหญ่บ้าน (balance.json → leaders)
| id | ไทย | English | mods |
|---|---|---|---|
| farmer | ชาวนา | Farmer | harvest_paddy_bonus add 1 |
| carpenter | ช่างไม้ | Carpenter | house_wood add −1, stilt_wood add −1, raft_wood add −1 |
| fisher | ชาวประมง | Fisher | fish_trap_yield add 1 |
| soil_doctor | หมอดิน | Soil Doctor | dig_labor_dry add −1, dig_labor_rain add −1, fill_labor_dry add −1, fill_labor_rain add −1 |

## [M-05] การ์ด 30 ใบ (data/cards.json)
รูปแบบแต่ละใบ: {"id": "...", "mods": [ ... ]} ส่วนชื่อและคำอธิบายอยู่ใน strings.csv (card.<id>.name / card.<id>.desc)

| # | id | ไทย | English | mods | คำอธิบาย (ไทย) |
|---|---|---|---|---|---|
| 1 | waterwheel | ระหัดวิดน้ำ | Waterwheel | unlock_waterwheel set 1 | ปลดล็อกระหัด: ทุกเทิร์นดึงน้ำ 0.5 จากช่องข้างเคียงเข้ามา |
| 2 | floating_rice | ข้าวขึ้นน้ำ | Floating Rice | paddy_max_level set 2; paddy_death_level set 3 | นาให้ผลที่น้ำระดับ 1–2 และตายที่ระดับ 3 |
| 3 | raft_house | เรือนแพ | Raft House | unlock_raft_house set 1 | ปลดล็อกเรือนแพ: สร้างบนน้ำ ไม่มีวันพัง |
| 4 | sandbags | กระสอบทราย | Sandbags | fill_labor_rain set 2 | ถมดินช่วงฝนใช้แรงงาน 2 |
| 5 | long_khaek | ลงแขก | Long Khaek | season_first_turn_labor add 3 | เทิร์นแรกของแต่ละฤดู แรงงาน +3 |
| 6 | pla_ra | ปลาร้า | Fermented Fish | rot_fraction set 0.25 | ไม่มียุ้งฉาง อาหารเน่าแค่ 25% |
| 7 | flooded_forest | ป่าทาม | Flooded Forest | forest_absorb set 0.6 | ป่าซับน้ำ 0.6 ต่อเทิร์น |
| 8 | canal_network | คลองซอย | Canal Network | dig_labor_dry set 1 | ขุดช่วงแล้งใช้แรงงาน 1 |
| 9 | sky_reader | หมอดูฟ้า | Sky Reader | reveal_all_inflow set 1 | เห็นน้ำเข้าทุกเทิร์นฝนตั้งแต่ต้นปี |
| 10 | jasmine_rice | ข้าวหอมมะลิ | Jasmine Rice | jasmine_bonus add 2 | นาที่ให้ผลครบ 3 เทิร์นฝน ได้ +2 ตอนเก็บเกี่ยว |
| 11 | bamboo | ไผ่ | Bamboo | chop_wood add 1 | ตัดไม้ได้เพิ่ม +1 |
| 12 | deep_piles | เสาตอม่อ | Deep Piles | stilt_destroy_level set 3 | เรือนใต้ถุนสูงพังที่น้ำระดับ 3 |
| 13 | nursery | เรือนเพาะชำ | Tree Nursery | sapling_absorb set 0.15 | ป่าอ่อนซับน้ำ 0.15 ต่อเทิร์น |
| 14 | clay_soil | ดินเหนียว | Clay Soil | fill_labor_dry set 1 | ถมช่วงแล้งใช้แรงงาน 1 |
| 15 | big_granary | ยุ้งฉางใหญ่ | Great Granary | granary_wood add −2; granary_destroy_level set 3 | ยุ้งฉางใช้ไม้น้อยลง 2 และทนน้ำถึงระดับ 2 |
| 16 | dried_fish | ปลาแห้ง | Dried Fish | fish_trap_yield add 1 | ไซดักปลาได้อาหารเพิ่ม +1 |
| 17 | rice_blessing | ทำขวัญข้าว | Rice Spirit Rite | year_start_food add 2 | อาหาร +2 ทุกต้นปี |
| 18 | driftwood | ขอนไม้ลอยน้ำ | Driftwood | year_start_wood add 2 | ไม้ +2 ทุกต้นปี |
| 19 | earthworks | ทำนบดิน | Earthworks | fill_amount set 2 | ถมครั้งเดียวสูงขึ้น 2 ระดับ |
| 20 | dredging | ขุดลอกคลอง | Dredging | dig_amount set 2 | ขุดครั้งเดียวลึกลง 2 ระดับ |
| 21 | open_channels | ร่องน้ำไหลดี | Open Channels | flow_rate add 0.1 | น้ำไหลเร็วขึ้น |
| 22 | extended_family | ครอบครัวใหญ่ | Extended Family | home_capacity_bonus add 1 | บ้านทุกแบบอยู่ได้เพิ่ม +1 คน |
| 23 | river_silt | ตะกอนดิน | River Silt | fertile_silt_bonus add 1 | นาริมแม่น้ำได้ +1 ตอนเก็บเกี่ยว |
| 24 | broadcast_sowing | นาหว่าน | Broadcast Sowing | paddy_labor set 0 | ทำนาไม่ใช้แรงงาน |
| 25 | night_watch | เวรยามเฝ้าน้ำ | Night Watch | rain_turn_labor add 1 | ทุกเทิร์นฝน แรงงาน +1 |
| 26 | village_pond | บ่อชุมชน | Village Pond | reservoir_labor add −2 | ขุดบึงใช้แรงงานน้อยลง 2 |
| 27 | gate_craft | ช่างประตูน้ำ | Gatewright | gate_wood set 0; gate_labor add −1 | ประตูน้ำไม่ใช้ไม้ และใช้แรงงานน้อยลง 1 |
| 28 | salvage | เก็บของเก่า | Salvage | demolish_refund_fraction set 1 | รื้อถอนได้ไม้คืนเต็มจำนวน |
| 29 | midwife | หมอตำแย | Midwife | food_per_growth set 1 | อาหาร 1 หน่วยต่อคนเกิดใหม่ 1 คน |
| 30 | raised_floor | บ้านยกพื้น | Raised Floors | house_destroy_level set 2 | บ้านธรรมดาทนน้ำได้ถึงระดับ 1 |

## [M-06] แผนที่ (balance.json → maps)
- plains: ไม่มี mod
- valley: flow_rate set 0.7
- estuary: sea_level_rain set 0.6

## [M-07] ความยาก (balance.json → difficulty_levels; สะสมจากระดับ 1 ถึงระดับที่เลือก)
| ระดับ | mods | ข้อความ |
|---|---|---|
| 1 | rain_inflow_multiplier mul 1.1 | ฝนแรงขึ้น 10% |
| 2 | start_food add −2 | อาหารเริ่มต้น −2 |
| 3 | forecast_range_multiplier mul 1.5 | พยากรณ์คลาดเคลื่อนมากขึ้น |
| 4 | house_wood add 1; stilt_wood add 1 | บ้านใช้ไม้ +1 |
| 5 | rain_inflow_multiplier mul 1.1 | ฝนแรงขึ้นอีก 10% |
| 6 | card_offer_count set 2 | เลือกการ์ดจาก 2 ใบ |
| 7 | start_population add −2 | ประชากรเริ่มต้น −2 |
| 8 | rot_fraction add 0.25 | อาหารเน่าเพิ่ม 25% |
| 9 | forest_absorb mul 0.5 | ป่าซับน้ำได้ครึ่งเดียว |
| 10 | year5_inflow_multiplier mul 1.2 | มหาอุทกภัยแรงขึ้น 20% |