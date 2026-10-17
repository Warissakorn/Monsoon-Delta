class_name MainMenu
extends Control
## Menu and setup never modify a normal checkpoint. Boot owns game creation.

signal start_requested(config: Dictionary)
signal continue_requested()
signal sandbox_requested()
signal language_changed(language: String)
signal quit_requested()

const LEADERS: Array[String] = ["farmer", "carpenter", "fisher", "soil_doctor"]

var save_path: String = SaveIO.DEFAULT_PATH
var initial_seed: int = 42
var language: String = "th"

var _colors: Dictionary
var _home: VBoxContainer
var _setup: VBoxContainer
var _credits: VBoxContainer
var _continue_button: Button
var _seed_input: LineEdit
var _leader_option: OptionButton
var _leader_description: Label
var _error_panel: PanelContainer
var _error_label: Label
var _error_key: String = ""
var _overwrite_dialog: ConfirmationDialog
var _pending_config: Dictionary = {}


class DeltaIllustration extends Control:
	var colors: Dictionary

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if colors.is_empty():
			return
		var unit: float = minf(size.x / 9.5, size.y / 8.0)
		var origin: Vector2 = Vector2(size.x * 0.5, size.y * 0.48)
		for r: int in range(-3, 4):
			for q: int in range(-3, 4):
				if absi(q + r) > 3:
					continue
				var center: Vector2 = origin + Vector2(sqrt(3.0) * (q + r * 0.5), r * 1.5) * unit * 0.7
				var radius: float = unit * 0.68
				var river: bool = q == -1 or (r >= 1 and q == 0)
				var shade: Color = Color(colors.water_deep) if river else Color(colors.terrain_low)
				if not river and (q - r) % 3 == 0:
					shade = Color(colors.terrain_high)
				var points: PackedVector2Array = PackedVector2Array()
				for corner: int in range(6):
					points.append(center + Vector2.from_angle(deg_to_rad(30.0 + corner * 60.0)) * radius)
				draw_colored_polygon(points, shade)
				if river:
					draw_line(center + Vector2(-radius * 0.3, 0), center + Vector2(radius * 0.3, 0), Color(colors.water_shallow, 0.7), 2.0, true)
				elif q == 1 and r in [-1, 0, 1]:
					var house: Rect2 = Rect2(center - Vector2(radius * 0.28, 0), Vector2(radius * 0.56, radius * 0.42))
					draw_rect(house, Color(colors.house))
					draw_colored_polygon(PackedVector2Array([
						center + Vector2(-radius * 0.42, 0), center + Vector2(0, -radius * 0.4), center + Vector2(radius * 0.42, 0),
					]), Color(colors.roof))
				elif q >= 1 or q <= -2:
					draw_line(center + Vector2(0, radius * 0.3), center - Vector2(0, radius * 0.15), Color(colors.earth), radius * 0.1)
					draw_circle(center - Vector2(0, radius * 0.16), radius * 0.32, Color(colors.forest))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_colors = ThemeBuilder.palette()
	theme = ThemeBuilder.build()
	_build_ui()
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


func _button(key: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = tr(key)
	button.custom_minimum_size.y = 52
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(_colors.background)
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
	var columns: HBoxContainer = HBoxContainer.new()
	columns.custom_minimum_size = Vector2(1160, 632)
	columns.add_theme_constant_override("separation", 44)
	center.add_child(columns)
	var introduction: VBoxContainer = VBoxContainer.new()
	introduction.custom_minimum_size.x = 540
	introduction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	introduction.add_theme_constant_override("separation", 20)
	columns.add_child(introduction)
	introduction.add_child(_label("app.title", "Title"))
	introduction.add_child(_label("app.subtitle", "", true))
	var illustration: DeltaIllustration = DeltaIllustration.new()
	illustration.colors = _colors
	illustration.custom_minimum_size.y = 320
	illustration.size_flags_vertical = Control.SIZE_EXPAND_FILL
	introduction.add_child(illustration)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 576
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
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
	content.add_child(scroll)
	var pages: VBoxContainer = VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	_build_home(pages)
	_build_setup(pages)
	_build_credits(pages)
	_overwrite_dialog = ConfirmationDialog.new()
	_overwrite_dialog.title = tr("menu.overwrite_title")
	_overwrite_dialog.dialog_text = tr("menu.overwrite_body")
	_overwrite_dialog.ok_button_text = tr("menu.overwrite_confirm")
	_overwrite_dialog.cancel_button_text = tr("action.cancel")
	_overwrite_dialog.confirmed.connect(_confirm_start)
	_overwrite_dialog.canceled.connect(func(): _pending_config.clear())
	add_child(_overwrite_dialog)
	_show_page(_home)


func _build_home(parent: Node) -> void:
	_home = VBoxContainer.new()
	_home.add_theme_constant_override("separation", 14)
	parent.add_child(_home)
	_continue_button = _button("menu.continue", func(): continue_requested.emit())
	_home.add_child(_continue_button)
	_home.add_child(_button("menu.new_game", func(): _show_page(_setup)))
	_home.add_child(_button("menu.sandbox", func(): sandbox_requested.emit()))
	var language_button: Button = _button("menu.language", _change_language)
	language_button.text += " · " + tr("language.en" if language == "th" else "language.th")
	_home.add_child(language_button)
	_home.add_child(_button("menu.credits", func(): _show_page(_credits)))
	_home.add_child(_button("menu.quit", func(): quit_requested.emit()))


func _build_setup(parent: Node) -> void:
	_setup = VBoxContainer.new()
	_setup.add_theme_constant_override("separation", 12)
	parent.add_child(_setup)
	_setup.add_child(_label("setup.title", "Heading"))
	_setup.add_child(_label("setup.leader", "", true))
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
	var map_row: HBoxContainer = HBoxContainer.new()
	_setup.add_child(map_row)
	map_row.add_child(_label("setup.map", "", true))
	map_row.add_child(_label("map.plains.name"))
	var difficulty_row: HBoxContainer = HBoxContainer.new()
	_setup.add_child(difficulty_row)
	difficulty_row.add_child(_label("setup.difficulty", "", true))
	difficulty_row.add_child(_label("setup.difficulty_zero"))
	_setup.add_child(_label("setup.seed", "", true))
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
	var play: Button = _button("menu.play", _request_start)
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
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and not focus.is_visible_in_tree():
		focus.release_focus()


func _select_leader(index: int) -> void:
	_leader_description.text = tr("leader." + LEADERS[index] + ".desc")


func _change_language() -> void:
	language_changed.emit("en" if language == "th" else "th")


func _request_start() -> void:
	if _overwrite_dialog.visible:
		return
	_pending_config = {
		"seed": SeedUtil.parse_seed_text(_seed_input.text),
		"map_type": "plains",
		"leader": LEADERS[_leader_option.selected],
		"difficulty": 0,
	}
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
	start_requested.emit(config)
