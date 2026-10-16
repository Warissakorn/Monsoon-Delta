# 01 สถาปัตยกรรม

## กฎการพึ่งพา [A-01]
- `core/` = ตรรกะล้วน: extends RefCounted หรือเป็น static func เท่านั้น
  - ห้ามอ้าง Node, SceneTree, Input, OS.get_ticks*, Time.*, randf()/randi() แบบ global
  - ใช้ FileAccess ได้ (save/load/data)
- `view/` (3D) และ `ui/` (2D) อ่าน GameState ได้ แต่เปลี่ยน state ได้ทางเดียว คือเรียก API ใน GameFlow / CommandRules
- `core/` ห้าม preload หรืออ้างไฟล์ใน view/, ui/, tools/
- ค่าที่ปรับสมดุลได้ทั้งหมดอยู่ใน data/*.json ห้าม hardcode ใน .gd
- ห้ามมีไฟล์โมเดล 3D หรือรูปภาพในเกม ภาพทั้งหมดสร้างจากโค้ด (ยกเว้นไอคอนแอปใน M9)

## ไฟล์ทั้งหมด (ห้ามเพิ่มไฟล์นอกรายการโดยไม่บันทึกเหตุผลใน PROGRESS.md)

### core/
| ไฟล์ | class_name | หน้าที่ |
|---|---|---|
| constants.gd | C | enum ทั้งหมด (ด้านล่าง) |
| hex.gd | Hex | ฟังก์ชันคณิตศาสตร์ hex แบบ static (03) |
| seed_util.gd | SeedUtil | fnv1a32(), derive_seed(), parse_seed_text() (03) |
| data_db.gd | DataDB | โหลด data/*.json ครั้งเดียวแล้ว cache (static) |
| tile.gd | Tile | ข้อมูลช่อง (02) |
| game_state.gd | GameState | สถานะเกม (02) |
| mods.gd | Mods | รวม modifier เป็นค่าจริง (07) |
| map_gen.gd | MapGen | สร้างแผนที่ (03) |
| water_sim.gd | WaterSim | จำลองน้ำ (04) |
| command.gd | Command | ข้อมูลคำสั่ง: id:String, coord:Vector2i, param:int = -1 |
| command_rules.gd | CommandRules | check(), cost(), apply() (05) |
| turn_resolver.gd | TurnResolver | resolve_turn() (06) |
| turn_report.gd | TurnReport | ผลของ 1 เทิร์น (06) |
| harvest.gd | Harvest | do_harvest() (06) |
| forecast.gd | Forecast | สร้างพยากรณ์ (06) |
| events.gd | Events | สุ่มและใช้ผลเหตุการณ์ (08) |
| game_flow.gd | GameFlow | API หลักที่ UI เรียก (06) |
| undo_stack.gd | UndoStack | ย้อนการกระทำ (02) |
| scoring.gd | Scoring | คิดคะแนน (09) |
| profile.gd | Profile | ข้อมูลข้ามรอบและการปลดล็อก (09) |
| save_io.gd | SaveIO | อ่าน/เขียน JSON ใน user:// (02) |

### view/ (Node3D)
| ไฟล์ | หน้าที่ |
|---|---|
| board_view.gd | สร้างและอัปเดตช่องทั้งหมด, picking, ไฮไลต์ |
| tile_view.gd | 1 ช่อง: ตัวช่อง, ป่า/นา, สิ่งก่อสร้าง, น้ำ, ผีพรีวิว, ป้ายตัวเลข |
| mesh_lib.gd | ฟังก์ชันสร้าง mesh ทุกชนิด (11) |
| water_anim.gd | เล่นแอนิเมชันน้ำจาก snapshot |
| camera_rig.gd | กล้อง (10) |
| weather.gd | แสง ท้องฟ้า ฝน ตามฤดู |
| fx.gd | tween, จอสั่น, ตัวเลขลอย |

### ui/ (Control)
| ไฟล์ | หน้าที่ |
|---|---|
| boot.gd + boot.tscn | main scene: อ่านอาร์กิวเมนต์บรรทัดคำสั่ง แล้วไปหน้าที่ถูกต้อง |
| app.gd | autoload "App": เปลี่ยนหน้า, settings, profile, ถ่ายภาพหน้าจอ |
| audio.gd | autoload "Audio" (12) |
| theme_builder.gd | สร้าง Theme จาก palette (10) |
| main_menu.gd | เมนูหลัก |
| new_game_screen.gd | ตั้งค่ารอบใหม่ |
| game_screen.gd | ถือ GameState, เชื่อม view + HUD + input |
| top_bar.gd / command_bar.gd / tile_info_panel.gd / preview_panel.gd | ส่วนของ HUD |
| card_dialog.gd / event_dialog.gd / year_summary_dialog.gd / game_over_dialog.gd / pause_menu.gd / confirm_dialog.gd | หน้าต่างซ้อน |
| settings_screen.gd / credits_screen.gd | หน้าตั้งค่าและเครดิต |
| tutorial.gd | บทสอนเล่น |
| sandbox_screen.gd | หน้าทดลองน้ำของ M2 (เก็บไว้เป็นโหมดดีบัก) |

### อื่น ๆ
- tools/bot_sim.gd, tools/bot_farmer.gd, tools/bot_greedy.gd (14)
- tests/run_tests.gd, tests/test_case.gd, tests/test_maps.gd, tests/test_*.gd (14)
- data/balance.json, data/cards.json, data/events.json, data/palette.json, data/audio.json
- shaders/water.gdshader, shaders/tile.gdshader (ถ้าจำเป็น)
- translations/strings.csv
- assets/fonts/, assets/audio/ (ผู้ใช้หามาใส่)

## enum ใน core/constants.gd [A-02]
```gdscript
class_name C
enum Season { DRY, RAIN }
enum Phase { CARD_PICK, EVENT, PLANNING, HARVEST, GAME_OVER }
enum Feature { NONE, FOREST, SAPLING, PADDY }
enum Building { NONE, HALL, HOUSE, STILT_HOUSE, RAFT_HOUSE, GATE, GRANARY, FISH_TRAP, RESERVOIR, WATERWHEEL }
enum Outcome { NONE, WIN, LOSE_HALL, LOSE_POPULATION }
const EPS: float = 1e-6
const MAP_RADIUS: int = 4
const YEARS: int = 5
const TURNS_PER_YEAR: int = 6
const DRY_TURNS: int = 3
const HEIGHT_UNIT: float = 0.4  # world units per elevation step
```
ใน JSON และเซฟ enum ต้องเก็บเป็นชื่อ string ตัวพิมพ์เล็ก (เช่น "stilt_house") ไม่ใช่ตัวเลข

## Project settings [A-03]
- application/run/main_scene = res://ui/boot.tscn
- rendering/renderer/rendering_method = gl_compatibility
- display/window/size/viewport_width = 1920, viewport_height = 1080
- display/window/size/window_width_override = 1600, window_height_override = 900
- display/window/stretch/mode = canvas_items, aspect = expand
- rendering/anti_aliasing/quality/msaa_3d = 2 (4x)
- internationalization/locale/include_text_server_data = true
- internationalization/locale/translations = translations/strings.th.translation, strings.en.translation
- autoload: App = res://ui/app.gd, Audio = res://ui/audio.gd
- Input Map: ตาม 10_ui.md

## อาร์กิวเมนต์บรรทัดคำสั่ง (อ่านใน boot.gd ผ่าน OS.get_cmdline_user_args()) [A-04]
| อาร์กิวเมนต์ | ผล |
|---|---|
| --scene=menu\|game\|sandbox | หน้าเริ่มต้น (ค่าเริ่มต้น menu) |
| --seed=N | ใช้ seed นี้ (scene game/sandbox) |
| --map=plains\|valley\|estuary | แผนที่ (scene game) |
| --lang=th\|en | บังคับภาษา |
| --screenshot=path.png | รอ 30 เฟรม (และรอแอนิเมชันจบ) → บันทึก PNG → ออกจากเกม |
| --dialog=card\|event\|summary\|gameover | เปิดหน้าต่างนี้ทันทีด้วยข้อมูลตัวอย่าง (ใช้ตรวจภาพ) |