class_name MainMenu
extends Control
## Menu and setup never modify a normal checkpoint. Boot owns game creation.

signal start_requested(config: Dictionary)
signal continue_requested()
signal sandbox_requested()
signal lesson_requested(scenario_id: String)
signal language_changed(language: String)
signal quit_requested()

const LEADERS: Array[String] = ["farmer", "carpenter", "fisher", "soil_doctor"]
const RUN_MODES: Array[String] = ["classic", "long"]
const GOALS: Array[String] = ["none", "growth", "forest", "rice"]
const LandscapeArt: GDScript = preload("res://view/menu_landscape.gd")

var save_path: String = SaveIO.DEFAULT_PATH
var initial_seed: int = 42
var initial_difficulty: int = 0
var initial_ruleset: String = "legacy"
var language: String = "th"
var initial_school: bool = false

var _colors: Dictionary
var _home: VBoxContainer
var _setup: VBoxContainer
var _credits: VBoxContainer
var _school: VBoxContainer
var _school_button: Button
var _continue_button: Button
var _new_game_button: Button
var _columns: HBoxContainer
var _illustration: Control
var _title_label: Label
var _menu_panel: PanelContainer
var _seed_input: LineEdit
var _leader_option: OptionButton
var _leader_description: Label
var _run_mode_option: OptionButton
var _run_mode_description: Label
var _goal_option: OptionButton
var _goal_description: Label
var _difficulty_option: OptionButton
var _difficulty_description: Label
var _bracing_toggle: CheckBox
var _moisture_toggle: CheckBox
var _error_panel: PanelContainer
var _error_label: Label
var _error_key: String = ""
var _overwrite_dialog: ConfirmationDialog
var _pending_config: Dictionary = {}


class LagoonBackdrop extends Control:
	var colors: Dictionary

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if colors.is_empty():
			return
		var top: Color = Color(colors.lagoon).darkened(0.58)
		var bottom: Color = Color(colors.background)
		for row: int in range(64):
			var ratio: float = float(row) / 63.0
			draw_rect(Rect2(0, size.y * ratio, size.x, size.y / 63.0 + 1), top.lerp(bottom, ratio))
		var glow_center: Vector2 = size * Vector2(0.30, 0.46)
		for ring: int in range(24, 0, -1):
			draw_circle(glow_center, float(ring) * size.y / 22.0, Color(colors.lagoon, 0.018))
		for contour: int in range(9):
			var points: PackedVector2Array = PackedVector2Array()
			for step: int in range(49):
				var x: float = size.x * float(step) / 48.0
				var y: float = size.y * 0.82 + contour * 24.0 + sin(float(step) * 0.17 + contour * 0.19) * 46.0
				points.append(Vector2(x, y))
			draw_polyline(points, Color(colors.border, 0.16), 1.0, true)
		for speck: int in range(100):
			var point: Vector2 = Vector2(fmod(speck * 173.3, size.x), fmod(speck * 79.7, size.y))
			draw_circle(point, 0.7, Color(colors.paper, 0.06))


class MenuActionButton extends Button:
	var show_arrow: bool = false

	func _draw() -> void:
		if not show_arrow:
			return
		var color: Color = get_theme_color("font_color")
		var point: Vector2 = Vector2(size.x - 28, size.y * 0.5)
		draw_line(point - Vector2(15, 0), point, color, 1.7, true)
		draw_polyline(PackedVector2Array([point - Vector2(5, 5), point, point - Vector2(5, -5)]), color, 1.7, true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_colors = ThemeBuilder.palette()
	theme = ThemeBuilder.build()
	_build_ui()
	resized.connect(_update_layout)
	_update_layout()
	if initial_school:
		show_school()
	else:
		_validate_checkpoint()
	show_error(_error_key)


func show_error(key: String) -> void:
	_error_key = key
	if _error_panel == null:
		return
	_error_panel.visible = not key.is_empty()
	_error_label.text = tr(key) if not key.is_empty() else ""


func _validate_checkpoint() -> void:
	var exists: bool = SaveIO.has_save(save_path)
	var loaded: Dictionary = SaveIO.load_game(save_path)
	_continue_button.visible = exists and loaded["state"] != null
	_new_game_button.theme_type_variation = "QuietButton" if _continue_button.visible else "PrimaryButton"
	var error: String = loaded["error"]
	if not error.is_empty():
		show_error(error)


func _label(key: String, variant: String = "", muted: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = tr(key)
	label.theme_type_variation = variant
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if muted:
		label.add_theme_color_override("font_color", Color(_colors.muted))
	return label


func _button(key: String, callback: Callable, variant: String = "QuietButton", arrow: bool = false) -> Button:
	var button: MenuActionButton = MenuActionButton.new()
	button.text = tr(key)
	button.theme_type_variation = variant
	button.show_arrow = arrow
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if arrow else HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size.y = 58
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button


func _build_ui() -> void:
	var background: LagoonBackdrop = LagoonBackdrop.new()
	background.colors = _colors
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var center: CenterContainer = CenterContainer.new()
	margin.add_child(center)
	_columns = HBoxContainer.new()
	_columns.custom_minimum_size = Vector2(1160, 632)
	_columns.add_theme_constant_override("separation", 48)
	center.add_child(_columns)
	var introduction: VBoxContainer = VBoxContainer.new()
	introduction.custom_minimum_size.x = 540
	introduction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	introduction.add_theme_constant_override("separation", 20)
	_columns.add_child(introduction)
	var title_group: VBoxContainer = VBoxContainer.new()
	title_group.add_theme_constant_override("separation", 4)
	introduction.add_child(title_group)
	title_group.add_child(_label("map.plains.name", "Kicker"))
	_title_label = _label("app.title", "Title")
	_title_label.add_theme_color_override("font_shadow_color", Color(_colors.background, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_group.add_child(_title_label)
	_illustration = LandscapeArt.new()
	_illustration.set("colors", _colors)
	_illustration.custom_minimum_size.y = 340
	_illustration.size_flags_vertical = Control.SIZE_EXPAND_FILL
	introduction.add_child(_illustration)
	var seasons: HBoxContainer = HBoxContainer.new()
	seasons.add_theme_constant_override("separation", 24)
	introduction.add_child(seasons)
	seasons.add_child(_label("run_mode.classic.name", "Caption", true))
	var long_label: Label = _label("run_mode.long.name", "Caption", true)
	long_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seasons.add_child(long_label)
	_menu_panel = PanelContainer.new()
	_menu_panel.theme_type_variation = "CardPanel"
	_menu_panel.custom_minimum_size.x = 560
	var panel_style: StyleBoxFlat = theme.get_stylebox("panel", "CardPanel").duplicate() as StyleBoxFlat
	panel_style.set_content_margin_all(28)
	_menu_panel.add_theme_stylebox_override("panel", panel_style)
	_columns.add_child(_menu_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	_menu_panel.add_child(content)
	_error_panel = PanelContainer.new()
	_error_panel.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(_colors.accent, 0.13), 8, Color(_colors.accent, 0.5)))
	content.add_child(_error_panel)
	_error_label = _label("")
	_error_label.add_theme_font_size_override("font_size", 18)
	_error_label.add_theme_color_override("font_color", Color(_colors.accent))
	_error_panel.add_child(_error_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	content.add_child(scroll)
	var pages: VBoxContainer = VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	_build_home(pages)
	_build_setup(pages)
	_build_school(pages)
	_build_credits(pages)
	_overwrite_dialog = ConfirmationDialog.new()
	_overwrite_dialog.title = tr("menu.overwrite_title")
	_overwrite_dialog.dialog_text = tr("menu.overwrite_body")
	_overwrite_dialog.ok_button_text = tr("menu.overwrite_confirm")
	_overwrite_dialog.cancel_button_text = tr("action.cancel")
	_overwrite_dialog.confirmed.connect(_confirm_start)
	_overwrite_dialog.canceled.connect(func(): _pending_config.clear())
	_overwrite_dialog.get_ok_button().theme_type_variation = "PrimaryButton"
	_overwrite_dialog.get_cancel_button().theme_type_variation = "QuietButton"
	add_child(_overwrite_dialog)
	_show_page(_home)


func _update_layout() -> void:
	if _columns == null:
		return
	var available: Vector2 = get_viewport_rect().size
	_columns.custom_minimum_size = Vector2(clampf(available.x - 96.0, 1160.0, 1540.0), clampf(available.y - 112.0, 632.0, 820.0))
	_title_label.add_theme_font_size_override("font_size", 72 if available.x >= 1500.0 else 58)


func _build_home(parent: Node) -> void:
	_home = VBoxContainer.new()
	_home.add_theme_constant_override("separation", 14)
	_home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_home)
	_home.add_child(_label("setup.title", "Heading"))
	_home.add_child(_label("app.subtitle", "Caption", true))
	var top_space: Control = Control.new()
	top_space.custom_minimum_size.y = 10
	_home.add_child(top_space)
	_continue_button = _button("menu.continue", func(): continue_requested.emit(), "PrimaryButton", true)
	_home.add_child(_continue_button)
	_new_game_button = _button("menu.new_game", func(): _show_page(_setup), "PrimaryButton", true)
	_home.add_child(_new_game_button)
	_home.add_child(_button("menu.sandbox", func(): sandbox_requested.emit(), "QuietButton", true))
	_school_button = _button("school.title", show_school, "QuietButton", true)
	_school_button.name = "RiverSchool"
	_home.add_child(_school_button)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 24
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home.add_child(spacer)
	var utilities: HBoxContainer = HBoxContainer.new()
	_home.add_child(utilities)
	var language_button: Button = _button("menu.language", _change_language)
	language_button.text += " · " + tr("language.en" if language == "th" else "language.th")
	language_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	utilities.add_child(language_button)
	var credits_button: Button = _button("menu.credits", func(): _show_page(_credits))
	credits_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	utilities.add_child(credits_button)
	_home.add_child(_button("menu.quit", func(): quit_requested.emit()))


func show_school() -> void:
	_show_page(_school)
	var first: Button = _school.find_child("Lesson_river_school_01", true, false) as Button
	if first != null:
		first.grab_focus()


func _build_school(parent: Node) -> void:
	_school = VBoxContainer.new()
	_school.name = "RiverSchoolPage"
	_school.add_theme_constant_override("separation", 14)
	parent.add_child(_school)
	_school.add_child(_label("school.title", "Heading"))
	_school.add_child(_label("school.intro", "", true))
	_school.add_child(_label("school.no_checkpoint", "", true))
	for id: String in ["river_school_01", "river_school_03"]:
		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		_school.add_child(card)
		var content: VBoxContainer = VBoxContainer.new()
		content.add_theme_constant_override("separation", 8)
		card.add_child(content)
		content.add_child(_label("school." + id + ".name", "Heading"))
		content.add_child(_label("school." + id + ".goal"))
		var preparation: Label = _label("school." + id + ".prepared", "", true)
		preparation.add_theme_font_size_override("font_size", 16)
		content.add_child(preparation)
		var mastery: Label = _label("school." + id + ".mastery", "", true)
		mastery.add_theme_font_size_override("font_size", 16)
		content.add_child(mastery)
		var start: Button = _button("school.start", _request_lesson.bind(id), "PrimaryButton", true)
		start.name = "Lesson_" + id
		content.add_child(start)
	_school.add_child(_button("menu.back", _return_from_school))


func _return_from_school() -> void:
	# Opening practice directly does not need to inspect a normal checkpoint.
	# Check Continue only when the player explicitly returns to the home menu.
	_validate_checkpoint()
	_show_page(_home)


func _request_lesson(id: String) -> void:
	# Consume activation before the newly created board can see End Turn.
	get_viewport().set_input_as_handled()
	lesson_requested.emit(id)


func _build_setup(parent: Node) -> void:
	_setup = VBoxContainer.new()
	_setup.add_theme_constant_override("separation", 12)
	parent.add_child(_setup)
	_setup.add_child(_label("setup.title", "Heading"))
	_setup.add_child(_label("setup.leader", "Kicker"))
	_leader_option = OptionButton.new()
	_leader_option.custom_minimum_size.y = 52
	for leader: String in LEADERS:
		_leader_option.add_item(tr("leader." + leader + ".name"))
	_leader_option.item_selected.connect(_select_leader)
	_setup.add_child(_leader_option)
	_leader_description = _label("leader.farmer.desc", "", true)
	_leader_description.custom_minimum_size.y = 58
	_leader_description.add_theme_font_size_override("font_size", 18)
	_setup.add_child(_leader_description)
	var run_options: HBoxContainer = HBoxContainer.new()
	run_options.add_theme_constant_override("separation", 20)
	_setup.add_child(run_options)
	var mode_column: VBoxContainer = VBoxContainer.new()
	mode_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_options.add_child(mode_column)
	mode_column.add_child(_label("setup.run_mode", "Kicker"))
	_run_mode_option = OptionButton.new()
	_run_mode_option.custom_minimum_size.y = 52
	_run_mode_option.clip_text = true
	for mode: String in RUN_MODES:
		_run_mode_option.add_item(tr("run_mode." + mode + ".name"))
	_run_mode_option.item_selected.connect(_select_run_mode)
	mode_column.add_child(_run_mode_option)
	_run_mode_description = _label("run_mode.classic.desc", "", true)
	_run_mode_description.add_theme_font_size_override("font_size", 18)
	mode_column.add_child(_run_mode_description)
	_select_run_mode(0)
	var goal_column: VBoxContainer = VBoxContainer.new()
	goal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_options.add_child(goal_column)
	goal_column.add_child(_label("setup.village_goal", "Kicker"))
	_goal_option = OptionButton.new()
	_goal_option.custom_minimum_size.y = 52
	_goal_option.clip_text = true
	for goal: String in GOALS:
		_goal_option.add_item(tr("goal." + goal + ".name"))
	_goal_option.item_selected.connect(_select_goal)
	goal_column.add_child(_goal_option)
	_goal_description = _label("goal.none.desc", "", true)
	_goal_description.add_theme_font_size_override("font_size", 18)
	goal_column.add_child(_goal_description)
	_select_goal(0)
	var map_row: HBoxContainer = HBoxContainer.new()
	_setup.add_child(map_row)
	map_row.add_child(_label("setup.map", "", true))
	map_row.add_child(_label("map.plains.name"))
	var difficulty_row: HBoxContainer = HBoxContainer.new()
	_setup.add_child(difficulty_row)
	difficulty_row.add_child(_label("setup.difficulty", "Kicker"))
	_difficulty_option = OptionButton.new()
	_difficulty_option.custom_minimum_size = Vector2(220, 52)
	_difficulty_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for level: int in range(11):
		_difficulty_option.add_item(DifficultyInfo.label(level), level)
	_difficulty_option.select(clampi(initial_difficulty, 0, 10))
	_difficulty_option.item_selected.connect(_select_difficulty)
	difficulty_row.add_child(_difficulty_option)
	_difficulty_description = _label("", "", true)
	_difficulty_description.add_theme_font_size_override("font_size", 16)
	_setup.add_child(_difficulty_description)
	_update_difficulty_description()
	_bracing_toggle = CheckBox.new()
	_bracing_toggle.name = "EnableBracing"
	_bracing_toggle.text = tr("setup.bracing")
	_bracing_toggle.tooltip_text = tr("setup.bracing_hint")
	_bracing_toggle.custom_minimum_size.y = 44
	_bracing_toggle.set_pressed_no_signal(initial_ruleset in ["bracing_v1", "bracing_moisture_v1"])
	_setup.add_child(_bracing_toggle)
	var bracing_hint: Label = _label("setup.bracing_hint", "", true)
	bracing_hint.add_theme_font_size_override("font_size", 16)
	_setup.add_child(bracing_hint)
	_moisture_toggle = CheckBox.new()
	_moisture_toggle.name = "EnableMoisture"
	_moisture_toggle.text = tr("setup.moisture")
	_moisture_toggle.tooltip_text = tr("setup.moisture_hint")
	_moisture_toggle.custom_minimum_size.y = 44
	_moisture_toggle.set_pressed_no_signal(initial_ruleset in ["moisture_v1", "bracing_moisture_v1"])
	_setup.add_child(_moisture_toggle)
	var moisture_hint: Label = _label("setup.moisture_hint", "", true)
	moisture_hint.add_theme_font_size_override("font_size", 16)
	_setup.add_child(moisture_hint)
	_setup.add_child(_label("setup.seed", "Kicker"))
	_seed_input = LineEdit.new()
	_seed_input.text = str(initial_seed)
	_seed_input.placeholder_text = tr("setup.seed_hint")
	_seed_input.tooltip_text = tr("setup.seed_hint")
	_seed_input.custom_minimum_size.y = 52
	_seed_input.text_submitted.connect(func(_value: String): _request_start())
	_setup.add_child(_seed_input)
	var buttons: HBoxContainer = HBoxContainer.new()
	_setup.add_child(buttons)
	var back: Button = _button("menu.back", func(): _show_page(_home))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(back)
	var play: Button = _button("menu.play", _request_start, "PrimaryButton", true)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(play)


func _build_credits(parent: Node) -> void:
	_credits = VBoxContainer.new()
	_credits.add_theme_constant_override("separation", 20)
	parent.add_child(_credits)
	_credits.add_child(_label("credits.title", "Heading"))
	_credits.add_child(_label("credits.body", "", true))
	_credits.add_child(_button("menu.back", func(): _show_page(_home)))


func _show_page(page: Control) -> void:
	_home.visible = page == _home
	_setup.visible = page == _setup
	_credits.visible = page == _credits
	_school.visible = page == _school
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and not focus.is_visible_in_tree():
		focus.release_focus()
	if page == _setup:
		_leader_option.grab_focus()


func _select_leader(index: int) -> void:
	_leader_description.text = tr("leader." + LEADERS[index] + ".desc")
	_update_difficulty_description()


func _select_run_mode(index: int) -> void:
	_run_mode_description.text = tr("run_mode." + RUN_MODES[index] + ".desc")
	_run_mode_option.tooltip_text = _run_mode_option.get_item_text(index) + "\n" + _run_mode_description.text
	_update_difficulty_description()


func _select_difficulty(_index: int) -> void:
	_update_difficulty_description()


func _update_difficulty_description() -> void:
	if _difficulty_description == null:
		return
	_difficulty_description.text = DifficultyInfo.description(_difficulty_option.get_selected_id(), LEADERS[_leader_option.selected], RUN_MODES[_run_mode_option.selected])
	_difficulty_option.tooltip_text = _difficulty_description.text


func _select_goal(index: int) -> void:
	_goal_description.text = tr("goal." + GOALS[index] + ".desc")
	_goal_option.tooltip_text = _goal_option.get_item_text(index) + "\n" + _goal_description.text


func _change_language() -> void:
	language_changed.emit("en" if language == "th" else "th")


func setup_draft() -> Dictionary:
	# Keep text seeds as typed; parsing belongs to the eventual Play request.
	return {
		"seed_text": _seed_input.text,
		"leader": LEADERS[_leader_option.selected],
		"run_mode": RUN_MODES[_run_mode_option.selected],
		"village_goal": GOALS[_goal_option.selected],
		"difficulty": _difficulty_option.get_selected_id(),
		"bracing": _bracing_toggle.button_pressed,
		"moisture": _moisture_toggle.button_pressed,
	}


func restore_setup_draft(draft: Dictionary) -> void:
	_seed_input.text = draft["seed_text"]
	_leader_option.select(LEADERS.find(draft["leader"]))
	_run_mode_option.select(RUN_MODES.find(draft["run_mode"]))
	_goal_option.select(GOALS.find(draft["village_goal"]))
	_difficulty_option.select(int(draft["difficulty"]))
	_bracing_toggle.set_pressed_no_signal(draft["bracing"])
	_moisture_toggle.set_pressed_no_signal(draft["moisture"])
	_select_leader(_leader_option.selected)
	_select_run_mode(_run_mode_option.selected)
	_select_goal(_goal_option.selected)


func _request_start() -> void:
	if _overwrite_dialog.visible:
		return
	_pending_config = {
		"seed": SeedUtil.parse_seed_text(_seed_input.text),
		"map_type": "plains",
		"leader": LEADERS[_leader_option.selected],
		"difficulty": _difficulty_option.get_selected_id(),
		"run_mode": RUN_MODES[_run_mode_option.selected],
		"village_goal": GOALS[_goal_option.selected],
	}
	var ruleset: String = GameState.ruleset_for(_bracing_toggle.button_pressed, _moisture_toggle.button_pressed)
	if ruleset != "legacy":
		_pending_config["ruleset"] = ruleset
	# Existing files are protected even if a temporary read failure disabled
	# Continue. Opening the setup form itself never changes the checkpoint.
	if SaveIO.has_save(save_path):
		_overwrite_dialog.popup_centered(Vector2i(560, 220))
	else:
		_confirm_start()


func _confirm_start() -> void:
	if _pending_config.is_empty():
		return
	var config: Dictionary = _pending_config.duplicate(true)
	_pending_config.clear()
	# Boot replaces this screen synchronously. Consume the activation event
	# before its remaining propagation can reach the new game's End Turn action.
	get_viewport().set_input_as_handled()
	start_requested.emit(config)
