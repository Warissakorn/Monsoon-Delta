# 04 ระบบน้ำ

## หน่วยและระดับ [W-01, W-02]
- [W-01] ความสูง 1 ระดับ = น้ำ 1.0 และ surface = elevation + water
- [W-02] ระดับน้ำ (level):

| level | ชื่อ | เงื่อนไข |
|---|---|---|
| 0 | แห้ง | water < 0.1 |
| 1 | ตื้น | 0.1 ≤ water < 0.5 |
| 2 | ท่วม | 0.5 ≤ water < 1.0 |
| 3 | ลึก | water ≥ 1.0 |

## API
```gdscript
class_name WaterSim
# ทำ [W-03] ถึง [W-05] แล้วคืนผล; ห้ามใช้ rng
static func simulate(s: GameState, inflow: float, record_snapshots: bool) -> Dictionary
# คืน { "inflow": float, "to_sea": float, "from_sea": float, "wheel_moved": float,
#       "snapshots": Array[PackedFloat32Array] }  # snapshot = water ทุกช่องตามลำดับ index
static func absorb(s: GameState) -> float        # [W-06] คืนปริมาณที่ซับไป
static func evaporate(s: GameState) -> float     # [W-07] คืนปริมาณที่ระเหย (เรียกเฉพาะฤดูแล้ง)
```

## [W-03] ระหัดวิดน้ำ (ทำครั้งเดียวก่อนเริ่ม iteration)
- วนช่อง WATERWHEEL ตามลำดับ index:
  - src = neighbor_in_dir(wheel, wheel_dir)
  - ถ้า src ไม่มี เป็นทะเล หรือเป็นประตูที่ปิดอยู่ → ข้าม
  - amt = min(mod.wheel_amount, src.water); src.water −= amt; wheel.water += amt

## [W-04] iteration (ทำ N = mod.water_iterations ครั้ง)
```text
sources = ช่อง is_source ทั้งหมด
sea_level = mod.sea_level_dry ถ้าฤดูแล้ง, mod.sea_level_rain ถ้าฤดูฝน
flow = clampf(mod.flow_rate, 0.05, 0.9)
snapshots.append(water ปัจจุบัน) ถ้า record_snapshots   # snapshot เริ่มต้น

ทำซ้ำ N ครั้ง:
  1. ทุก source: water += inflow / N / sources.size()
  2. surf[i] = elevation + water ของทุกช่อง (คิดจากค่าก่อน iteration นี้)
  3. delta[i] = 0 ทุกช่อง
  4. วนทุกช่อง i ตามลำดับ index:
       ข้ามถ้า water[i] <= EPS หรือ i เป็นประตูที่ปิดอยู่
       lower = เพื่อนบ้าน j (ตามลำดับทิศ) ที่ไม่ใช่ประตูปิด และ d = surf[i] − surf[j] > EPS
       ถ้า lower ว่าง → ข้าม
       total = Σ d
       out = min(water[i], total / (lower.size() + 1) × flow)
       ทุก j: share = out × d_j / total; delta[j] += share; delta[i] −= share
              ถ้า i ไม่ใช่ทะเลและ j เป็นทะเล → to_sea += share
              ถ้า i เป็นทะเลและ j ไม่ใช่ทะเล → from_sea += share
  5. water[i] += delta[i] ทุกช่อง; ถ้า water < 0 ให้เป็น 0 (ถ้าติดลบเกิน −1e-4 ให้ push_error)
  6. ทุกช่องทะเล: water = sea_level
  7. snapshots.append(water) ถ้า record_snapshots
```
- ผลคือ snapshots มี N + 1 ชุด

## [W-05] ประตูน้ำที่ปิด
- ไม่ส่งน้ำออกและไม่รับน้ำเข้า แต่น้ำที่ค้างในช่องยังอยู่
- ประตูที่เปิดทำตัวเหมือนช่องปกติ

## [W-06] การซับน้ำ (หลังจำลอง)
- feature FOREST: ซับ min(water, mod.forest_absorb)
- feature SAPLING: ซับ min(water, mod.sapling_absorb)
- ทะเลไม่ซับ

## [W-07] การระเหย (ฤดูแล้งเท่านั้น หลังการซับ)
- ทุกช่องที่ไม่ใช่ทะเล: water −= min(water, mod.evaporation_dry × mod.evaporation_multiplier)

## [W-08] การอนุรักษ์มวล (ต้องเป็นจริงเสมอ คลาดเคลื่อนได้ ≤ 1e-3)
- ให้ L = ผลรวมน้ำของช่องที่ไม่ใช่ทะเล
- L_หลัง − L_ก่อน = inflow − to_sea + from_sea − absorbed − evaporated
- ระหัดวิดน้ำย้ายน้ำภายใน ไม่เปลี่ยน L

## [W-09] ห้ามไหลขึ้นที่สูง
- ใน iteration เดียว น้ำย้ายจาก i ไป j ได้เฉพาะเมื่อ surf[i] > surf[j] ก่อน iteration นั้น