extends Node
## M2 water laboratory. All changes to terrain/water go through GameFlow.

var initial_seed: int = 42
var language: String = "th"
var state: GameState
var board: BoardView
var camera_rig: CameraRig
var hud: Control
var seed_input: LineEdit
var tile_title: Label
var tile_stats: Label
var tile_note: Label
var volume_label: Label
var report_label: Label
var status_label: Label
var step_label: Label
var step_button: Button
var dig_button: Button
var fill_button: Button
var hovered: Tile
var tool_amount: int = -1
var rain_steps: int = 0
var show_levels: bool = false
var colors: Dictionary

func txt(th: String, en: String) -> String:
	return th if language == "th" else en

func _ready() -> void:
	colors = ThemeBuilder.palette()
	_build_world()
	_build_hud()
	_new_map(initial_seed)

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(colors.background)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d7e4d2")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("#ffebc7")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	board = BoardView.new()
	add_child(board)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup()
	camera_rig.get_camera().h_offset = 1.9

func _label(text: String, size: int = 22, color: String = "ink") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(colors[color]))
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 56
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_release_text_focus)
	button.pressed.connect(callback)
	return button

func _release_text_focus() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		focus.release_focus()

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	return content

func _rule(parent: Node) -> void:
	var rule := HSeparator.new()
	rule.modulate = Color(colors.muted, 0.25)
	parent.add_child(rule)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = ThemeBuilder.build()
	canvas.add_child(hud)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(margin)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(_label("MONSOON DELTA", 38))
	title_box.add_child(_label(txt("ฤดูน้ำหลาก  /  ห้องทดลองสายน้ำ", "WATER LABORATORY  /  Shape the delta"), 22, "muted"))
	var stage := _label(txt("ต้นแบบ M2   •   61 ช่อง", "M2 PROTOTYPE   •   61 TILES"), 20, "accent")
	stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(stage)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(middle)
	var board_space := Control.new()
	board_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(board_space)
	var board_caption := _label(txt("ที่ราบลุ่ม\nขุดทางให้น้ำ • ถมดินเพื่อกั้น", "THE PLAINS\nCarve a channel. Raise a bank."), 21, "muted")
	board_caption.position = Vector2(14, 12)
	board_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_space.add_child(board_caption)
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 440
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(side_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 420
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(sidebar)
	var tile_panel := _panel(sidebar)
	tile_panel.add_child(_label(txt("สำรวจพื้นที่", "TILE INSPECTOR"), 18, "accent"))
	tile_title = _label("", 28)
	tile_panel.add_child(tile_title)
	tile_stats = _label("", 23)
	tile_panel.add_child(tile_stats)
	_rule(tile_panel)
	tile_note = _label("", 20, "muted")
	tile_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_note.custom_minimum_size = Vector2(380, 68)
	tile_panel.add_child(tile_note)
	var water_panel := _panel(sidebar)
	water_panel.add_child(_label(txt("สมุดบันทึกน้ำ", "WATER LEDGER"), 18, "accent"))
	volume_label = _label("", 28)
	water_panel.add_child(volume_label)
	report_label = _label("", 20, "muted")
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	water_panel.add_child(report_label)
	var seed_panel := _panel(sidebar)
	seed_panel.add_child(_label(txt("สร้างแผนที่จาก SEED", "MAP SEED"), 18, "accent"))
	var seed_row := HBoxContainer.new()
	seed_panel.add_child(seed_row)
	seed_input = LineEdit.new()
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.placeholder_text = "42"
	seed_input.text_submitted.connect(func(value: String): _new_map(SeedUtil.parse_seed_text(value)); seed_input.release_focus())
	seed_row.add_child(seed_input)
	seed_row.add_child(_button(txt("สร้าง", "Load"), func(): _new_map(SeedUtil.parse_seed_text(seed_input.text)); seed_input.release_focus()))
	var reset_row := HBoxContainer.new()
	seed_panel.add_child(reset_row)
	var replay := _button(txt("เริ่ม seed เดิม", "Reset seed"), func(): _new_map(state.seed))
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_row.add_child(replay)
	var next := _button(txt("แผนที่ใหม่  R", "Next map  R"), _next_map)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_row.add_child(next)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidebar.add_child(spacer)
	var help := _label(txt("Q / E  หมุน   •   ล้อเมาส์  ซูม\nW A S D  เลื่อน   •   V  ระดับน้ำ", "Q / E  orbit   •   Scroll  zoom\nW A S D  pan   •   V  water levels"), 19, "muted")
	sidebar.add_child(help)
	var toolbar := PanelContainer.new()
	layout.add_child(toolbar)
	var toolbar_content := HBoxContainer.new()
	toolbar.add_child(toolbar_content)
	var tools := VBoxContainer.new()
	tools.custom_minimum_size.x = 370
	toolbar_content.add_child(tools)
	tools.add_child(_label(txt("ปรับทางน้ำ  •  ไม่ใช้ทรัพยากร", "SHAPE THE LAND  •  Unlimited tools"), 18, "muted"))
	var tool_row := HBoxContainer.new()
	tools.add_child(tool_row)
	dig_button = _button(txt("ขุดดิน  1", "Dig  1"), func(): _set_tool(-1))
	fill_button = _button(txt("ถมดิน  2", "Raise  2"), func(): _set_tool(1))
	for button in [dig_button, fill_button]:
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tool_row.add_child(button)
	var note := VBoxContainer.new()
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar_content.add_child(note)
	status_label = _label("", 22)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(status_label)
	note.add_child(_label(txt("คลิกซ้ายใช้เครื่องมือ  •  คลิกขวาถมดิน", "Left click: selected tool  •  Right click: raise"), 18, "muted"))
	var turn_box := VBoxContainer.new()
	turn_box.custom_minimum_size.x = 330
	toolbar_content.add_child(turn_box)
	step_label = _label("", 18, "muted")
	turn_box.add_child(step_label)
	step_button = _button(txt("จำลองน้ำ +%.2f   Space", "Simulate +%.2f   Space") % float(DataDB.balance().sandbox.inflow), _step_water)
	turn_box.add_child(step_button)

func _new_map(seed_value: int) -> void:
	var next_state := GameFlow.sandbox_new(seed_value)
	if next_state == null:
		status_label.text = txt("สร้างแผนที่ไม่สำเร็จ ลอง seed อื่น", "Map generation failed. Try another seed.")
		return
	state = next_state
	rain_steps = 0
	hovered = null
	board.set_state(state)
	board.set_labels_visible(show_levels)
	seed_input.text = str(state.seed)
	report_label.text = txt("ป่าซับน้ำหลังการจำลอง\nไม่มีการระเหยในโหมดฤดูฝน", "Forests absorb after simulation\nNo evaporation in this rain sandbox")
	status_label.text = txt("ชี้ช่องเพื่อดูข้อมูล แล้วลองขุดทางน้ำ", "Hover a tile to inspect it, then carve a channel")
	_set_tool(tool_amount)
	_update_inspector()
	_update_totals()

func _next_map() -> void:
	_new_map(state.seed + 1)

func _set_tool(amount: int) -> void:
	tool_amount = amount
	dig_button.set_pressed_no_signal(amount == -1)
	fill_button.set_pressed_no_signal(amount == 1)

func _update_totals() -> void:
	var total := 0.0
	for tile in state.tiles:
		if not tile.is_sea:
			total += tile.water
	volume_label.text = txt("น้ำบนแผ่นดิน  %.2f", "Land water  %.2f") % total
	step_label.text = txt("ฤดูฝน  /  จำลองแล้ว %d ครั้ง", "RAIN  /  %d steps simulated") % rain_steps

func _update_inspector() -> void:
	if hovered == null:
		tile_title.text = txt("ชี้ช่องบนแผนที่", "Hover over a tile")
		tile_stats.text = txt("ความสูง   —\nความลึกน้ำ   —", "Elevation   —\nWater depth   —")
		tile_note.text = txt("ต้นน้ำ ทะเล ป่า และสิ่งก่อสร้าง\nได้รับการป้องกันจากเครื่องมือขุด–ถม", "Source, sea, forests and buildings are protected from terrain edits.")
		return
	var kind := txt("ที่ดิน", "Land")
	if hovered.is_source:
		kind = txt("ต้นน้ำ", "River source")
	elif hovered.is_sea:
		kind = txt("ทะเล", "Sea outlet")
	elif hovered.building == C.Building.HALL:
		kind = txt("ศาลากลางหมู่บ้าน", "Village hall")
	elif hovered.building == C.Building.HOUSE:
		kind = txt("บ้าน", "House")
	elif hovered.feature == C.Feature.FOREST:
		kind = txt("ป่า", "Forest")
	elif hovered.is_river:
		kind = txt("ลำน้ำ", "Riverbed")
	tile_title.text = "%s  (%d, %d)" % [kind, hovered.q, hovered.r]
	var levels_th := ["แห้ง", "ตื้น", "ท่วม", "ลึก"]
	var levels_en := ["Dry", "Shallow", "Flooded", "Deep"]
	var level := state.level_of(hovered)
	tile_stats.text = txt("ความสูง   %d\nความลึกน้ำ   %.2f  /  %s", "Elevation   %d\nWater depth   %.2f  /  %s") % [hovered.elevation, hovered.water, levels_th[level] if language == "th" else levels_en[level]]
	var protected := hovered.is_source or hovered.is_sea or hovered.building != C.Building.NONE or hovered.feature != C.Feature.NONE
	tile_note.text = txt("พื้นที่ป้องกัน • ขุดและถมไม่ได้", "Protected tile • terrain tools disabled") if protected else txt("ขุดเพื่อลดความสูง • ถมเพื่อเพิ่มความสูง\nช่วงความสูง %d ถึง %d", "Dig lowers terrain • Raise builds a bank\nElevation range %d to %d") % [int(DataDB.balance().sandbox.elevation_min), int(DataDB.balance().sandbox.elevation_max)]

func _step_water() -> void:
	var report := GameFlow.sandbox_step(state, float(DataDB.balance().sandbox.inflow))
	rain_steps += 1
	board.refresh()
	_update_totals()
	_update_inspector()
	report_label.text = txt("น้ำเข้า  +%.2f\nออกทะเล  −%.2f  /  จากทะเล  +%.2f\nป่าซับน้ำ  −%.2f\nคลาดเคลื่อนมวลน้ำ  %.6f", "Inflow  +%.2f\nTo sea  −%.2f  /  From sea  +%.2f\nAbsorbed  −%.2f\nMass balance error  %.6f") % [report.inflow, report.to_sea, report.from_sea, report.absorbed, report.balance_error]
	status_label.text = txt("จำลองครบ %d ขั้นแล้ว • ลองเปลี่ยนทางน้ำต่อ", "%d iterations complete • try changing the flow") % int(state.mod("water_iterations")) if report.valid else txt("พบความคลาดเคลื่อนในการจำลอง", "Simulation balance check failed")

func _process(delta: float) -> void:
	if state == null:
		return
	var editing_text := get_viewport().gui_get_focus_owner() is LineEdit
	if not editing_text:
		var pan := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		if pan != Vector2.ZERO:
			camera_rig.pan(pan.normalized(), delta)
	var next_hover: Tile = null
	if get_viewport().gui_get_hovered_control() == null:
		next_hover = board.pick(camera_rig.get_camera(), get_viewport().get_mouse_position())
	if next_hover != hovered:
		hovered = next_hover
		if hovered != null:
			board.hover(hovered.coord)
		else:
			board.clear_hover()
		_update_inspector()

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton and event.pressed:
		# Text fields consume their own clicks; an unhandled click returns to the board.
		_release_text_focus()
	elif get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE, KEY_ENTER: _step_water()
			KEY_R: _next_map()
			KEY_Q: camera_rig.rotate_step(-1)
			KEY_E: camera_rig.rotate_step(1)
			KEY_1: _set_tool(-1)
			KEY_2: _set_tool(1)
			KEY_V:
				show_levels = not show_levels
				board.set_labels_visible(show_levels)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_rig.zoom_step(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_rig.zoom_step(1)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var tile := board.pick(camera_rig.get_camera(), event.position)
			if tile == null:
				return
			var amount := 1 if event.button_index == MOUSE_BUTTON_RIGHT else tool_amount
			if GameFlow.sandbox_edit(state, tile.coord, amount):
				board.refresh()
				hovered = tile
				board.select(tile.coord)
				_update_inspector()
				status_label.text = txt("ปรับความสูงแล้ว • กด Space เพื่อดูน้ำไหล", "Terrain changed • press Space to see the flow")
			else:
				status_label.text = txt("ช่องนี้ป้องกันไว้ หรือถึงขีดจำกัดความสูงแล้ว", "This tile is protected or at its elevation limit")
