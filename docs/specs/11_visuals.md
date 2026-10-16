# 11 ภาพ

## [V-01] palette (data/palette.json, ค่า hex)
| key | สี |
|---|---|
| elev_neg | #5B4A3A |
| elev_0 | #8C7A55 |
| elev_1 | #A08C5E |
| elev_2 | #7FA05A |
| elev_3 | #6A8C4C |
| elev_4 | #8E9180 |
| tile_side | #6B5844 |
| sea_floor | #3B6E8F |
| paddy | #A8D46F |
| paddy_dead | #9C8A5A |
| forest | #2F6B3A |
| sapling | #6FAF5A |
| trunk | #5A4632 |
| wall | #E8D9B5 |
| roof | #B5533C |
| hall_roof | #C0392B |
| hall_trim | #D4A017 |
| granary | #C9A66B |
| gate | #4A4A4A |
| fish_trap | #A0784A |
| raft | #8B6B45 |
| wheel | #7A5C3A |
| water_shallow | #7FD3E6 (alpha 0.55) |
| water_deep | #1F4E79 (alpha 0.85) |
| highlight_ok | #5CB85C (alpha 0.35) |
| highlight_bad | #D9534F |
| hover | #FFFFFF |
| ui_bg | #1E2A2E (alpha 0.85) |
| ui_text | #F2EBDD |
| ui_accent | #E0A43A |
| ui_danger | #D9534F |
| ui_ok | #5CB85C |
| ui_disabled | #7A7A7A |
| sky_dry_top | #8EC9F0 |
| sky_dry_horizon | #F6E2B3 |
| sky_rain_top | #5E6B78 |
| sky_rain_horizon | #9AA5AE |
| light_dry | #FFE7C2 |
| light_rain | #C9D6E3 |

## [V-02] ช่อง
- CylinderMesh: radial_segments 6, รัศมีบนและล่าง 0.97, rings 0
- หมุนรอบแกน y จนจุดยอดมุมหนึ่งชี้ไปทาง −z (pointy-top) และ**ต้องตรวจด้วยภาพหน้าจอ**ว่าช่องต่อกันพอดี ไม่มีช่องโหว่หรือซ้อนกันผิด
- ผิวบนอยู่ที่ y = elevation × 0.4; ฐานอยู่ที่ y = −1.6 (ความสูง mesh = ผิวบน + 1.6)
- สีผิวบน: ตาม elev_* (ค่าติดลบใช้ elev_neg, ทะเลใช้ sea_floor, นาใช้ paddy/paddy_dead) และใช้วัสดุแยกสำหรับด้านข้าง (tile_side)
- ทำผิวบนเป็นแผ่น hex บาง ๆ ซ้อนบนตัวช่องเพื่อแยกสีบนกับด้านข้าง
- นาข้าว: เพิ่มแท่งบาง 0.04 × 0.02 × 1.2 จำนวน 4 แท่งเรียงขนานกัน สี paddy เข้มขึ้น 15%

## [V-03] สิ่งก่อสร้าง (วางบนผิวบน ขนาดเป็นหน่วยฉาก)
| ชนิด | ประกอบด้วย |
|---|---|
| ป่า | 3 ต้น: ลำต้นทรงกระบอก r0.05 h0.25 + กรวย r0.28 h0.6 วางที่ (±0.35, 0.2) แบบสามเหลี่ยม |
| ป่าอ่อน | กรวยเล็ก r0.12 h0.25 จำนวน 2 ต้น สี sapling |
| HOUSE | กล่อง 0.6 × 0.4 × 0.5 + หลังคาจั่ว (PrismMesh 0.7 × 0.3 × 0.6) |
| STILT_HOUSE | เสา 4 ต้น สูง 0.4 + HOUSE วางบนเสา |
| RAFT_HOUSE | แพ (กล่อง 0.8 × 0.1 × 0.7 สี raft) + HOUSE ย่อ 0.85 เท่า ลอยตามผิวน้ำ |
| HALL | ฐาน 0.8 × 0.15 × 0.8 + กล่อง 0.7 × 0.45 × 0.7 + หลังคาจั่วซ้อน 2 ชั้น (สี hall_roof ขอบ hall_trim) |
| GATE | เสา 2 ต้น สูง 0.8 + บาน 0.9 × 0.6 × 0.08 (ปิด = บานลง / เปิด = บานยกขึ้น 0.5, tween 0.3 วินาที) |
| GRANARY | ทรงกระบอก r0.3 h0.5 + กรวยหลังคา |
| FISH_TRAP | ทรงกระบอกโปร่ง (ทำจากเส้นตั้ง 8 แท่ง) สูง 0.3 |
| RESERVOIR | ขอบหินเตี้ย 6 ก้อนรอบช่อง (กล่อง 0.25 × 0.15 × 0.15) |
| WATERWHEEL | วงล้อ (TorusMesh r0.35) ตั้งฉากชี้ไปทาง wheel_dir + ใบพัด 6 แผ่น หมุนช้า ๆ |

## [V-04] น้ำ (shaders/water.gdshader)
- แสดงเมื่อ water ≥ 0.05
- เป็น "คอลัมน์น้ำ" CylinderMesh 6 ด้าน รัศมี 0.985 ตั้งแต่ผิวช่องถึงผิวน้ำ (ความสูงขั้นต่ำ 0.02)
- ใช้ ShaderMaterial แยกหนึ่งชิ้นต่อช่อง (ห้ามใช้ instance uniform)
- ผีพรีวิวใช้ shader เดียวกัน โดยตั้ง preview = 1
```glsl
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;
uniform vec4 shallow_color : source_color = vec4(0.498, 0.827, 0.902, 0.55);
uniform vec4 deep_color : source_color = vec4(0.122, 0.306, 0.475, 0.85);
uniform float depth = 0.0;
uniform float max_depth = 1.5;
uniform float wave_amp = 0.02;
uniform float preview = 0.0;
void vertex() {
    vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    if (VERTEX.y > 0.0) {
        VERTEX.y += (sin(w.x * 2.0 + TIME * 1.5) + cos(w.z * 2.3 + TIME * 1.2)) * wave_amp;
    }
}
void fragment() {
    float t = clamp(depth / max_depth, 0.0, 1.0);
    vec4 c = mix(shallow_color, deep_color, t);
    float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    ALBEDO = c.rgb + vec3(fres * 0.15) + vec3(preview * 0.3);
    ROUGHNESS = 0.15;
    ALPHA = mix(c.a, 0.3, preview);
}
```

## [V-05] แอนิเมชัน
- **น้ำไหลตอนจบเทิร์น:** เล่นจาก snapshots ทั้งหมดใน 1.5 วินาที (interpolate เชิงเส้นระหว่าง snapshot) ห้ามรับคำสั่งระหว่างเล่น กด Space เพื่อข้ามได้
- **หลังน้ำไหลจบ:** เล่นผลพัง/ตายพร้อมกันทุกช่อง
  - บ้านพัง: จมลง 0.3 + เอียง 20° และจางหาย 0.5 วินาที พร้อมจอสั่น 0.2 วินาที (แอมพลิจูด 0.15)
  - นาตาย: เปลี่ยนเป็นสี paddy_dead 0.4 วินาที
- **ตัวเลขลอย:** Label3D "+n" ลอยขึ้น 0.8 หน่วยใน 1 วินาทีแล้วจางหาย
- **ขุด/ถม:** tween ความสูงช่อง 0.25 วินาที (ease out)
- **สร้าง:** สเกลจาก 0 เป็น 1 ใน 0.3 วินาที (TRANS_BACK)
- **ไฮไลต์:** แผ่น hex บาง ๆ สี highlight_ok ลอยเหนือผิว 0.02 / ช่องที่ชี้ = เส้นขอบ hover

## [V-06] ฤดูและท้องฟ้า
- WorldEnvironment + ProceduralSkyMaterial ใช้สี sky_*
- DirectionalLight3D: ฤดูแล้ง rotation (−50°, −30°, 0), สี light_dry, energy 1.1 / ฤดูฝน rotation (−65°, −30°, 0), สี light_rain, energy 0.6
- เปลี่ยนฤดูด้วย tween 2 วินาที
- **ฝน:** CPUParticles3D (ห้ามใช้ GPUParticles3D)
  - เฉพาะฤดูฝน: 1500 อนุภาค, mesh เส้นบาง 0.01 × 0.3, ตกจาก y 10 ในกล่องขนาด 18 × 18
  - ความหนาแน่นตามน้ำเข้า: amount_ratio = clamp(inflow / 8, 0.3, 1)
- **ป้ายตัวเลข (กด V):** Label3D บนทุกช่อง แสดง "e2 · w1" (ความสูง · ระดับน้ำ)