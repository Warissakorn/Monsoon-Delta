class_name GameScreen
extends Node
## Presentation/controller for a run; GameSession alone owns checkpoints.

signal menu_requested
signal restart_requested(config: Dictionary)

const COMMANDS: Array[String] = [
	"dig", "fill", "paddy", "house", "stilt_house", "raft_house", "gate",
	"reservoir", "fish_trap", "granary", "chop", "plant", "waterwheel", "demolish", "brace_house",
]
const SHORTCUTS: Dictionary = {
	KEY_1: "dig", KEY_2: "fill", KEY_3: "paddy", KEY_4: "house", KEY_5: "stilt_house",
	KEY_6: "raft_house", KEY_7: "gate", KEY_8: "reservoir", KEY_9: "fish_trap",
	KEY_0: "granary", KEY_C: "chop", KEY_P: "plant", KEY_B: "waterwheel", KEY_X: "demolish", KEY_R: "brace_house",
}
const KEY_LABELS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "C", "P", "B", "X", "R"]
const Advisor = preload("res://ui/village_advisor.gd")
const Progress = preload("res://core/settlement_progress.gd")

var session: GameSession
var preferences_path: String = GamePreferences.DEFAULT_PATH
var reduced_motion: bool = false
var board: BoardView
var camera_rig: CameraRig
var hud: Control
var prediction: Dictionary = {}
var harvest_projection: Dictionary = {}
var harvest_prediction: Dictionary = {}
var command_mode: String = ""
var wheel_origin: Vector2i = BoardView.NO_COORD
var hovered_coord: Vector2i = BoardView.NO_COORD
var preview_enabled: bool = true
var show_levels: bool = false
var modal_kind: String = ""
var confirm_unused_labor: bool = true
var history_index: int = -1
var _history_return: String = ""
var _history_title: Label
var _history_details: VBoxContainer
var _history_previous: Button
var _history_next: Button
var _history_scroll: ScrollContainer
var _latest_panel: Control
var _latest_result: Label
var _modal: Control
var _modal_content: VBoxContainer
var _skip_confirmation: CheckBox
var _time_label: Label
var _resources_label: Label
var _water_label: Label
var _run_label: Label
var _goal_label: Label
var _goal_panel: Control
var _survival_help: Label
var _survival_progress: ProgressBar
var _condition_icon: TextureRect
var _condition_label: Label
var _resource_chips: Dictionary = {}
var _goal_bars: VBoxContainer
var _advisor: Dictionary = {}
var _advisor_panel: PanelContainer
var _advisor_icon: TextureRect
var _advisor_timing: Label
var _advisor_text: Label
var _advisor_button: Button
var _advisor_command: String = ""
var _advisor_coord: Vector2i = BoardView.NO_COORD
var _advisor_review: bool = false
var _inspection_focus: Vector2i = BoardView.NO_COORD
var _inspection_pointer: Vector2 = Vector2.ZERO
var _goal_preview_achieved: bool = false
var _save_label: Label
var _tile_title: Label
var _tile_details: Label
var _tile_note: Label
var _preview_label: Label
var _preview_legend: Label
var _status_label: Label
var _command_buttons: Dictionary = {}
var _commands_grid: GridContainer
var _targets: Dictionary = {}
var _preview_button: Button
var _undo_button: Button
var _redo_button: Button
var _end_button: Button
var _predicted_outcome: int = C.Outcome.NONE
var _preferences_error: String = ""
var _colors: Dictionary
var _atmosphere: DeltaAtmosphere
var _season_icon: TextureRect
var _turn_pips: Array[ColorRect] = []
var _feedback: ActionFeedback
var _motion_toggle: CheckBox
var _motion_error: Label
var _turn_feedback_active: bool = false


func _ready() -> void:
	_colors = ThemeBuilder.palette()
	var preferences: Dictionary = GamePreferences.read(preferences_path)
	confirm_unused_labor = bool(preferences["confirm_unused_labor"])
	reduced_motion = bool(preferences.get("reduced_motion", false))
	_build_world()
	_build_hud()
	_apply_motion_preference()
	if session == null or session.state == null:
		return
	refresh_state()
	if session.state.phase == C.Phase.HARVEST:
		_show_harvest()
	elif session.state.phase == C.Phase.GAME_OVER:
		_show_game_over()


func _build_world() -> void:
	_atmosphere = DeltaAtmosphere.new()
	add_child(_atmosphere)
	board = BoardView.new()
	add_child(board)
	_feedback = ActionFeedback.new()
	_feedback.name = "ActionFeedback"
	board.add_child(_feedback)
	_feedback.emptied.connect(_on_feedback_emptied)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup()
	camera_rig.get_camera().h_offset = 3.8
	camera_rig.get_camera().v_offset = -0.65


func _label(text: String = "", font_size: int = 20, muted: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if muted:
		label.add_theme_color_override("font_color", Color(_colors.muted))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, callback: Callable, node_name: String = "") -> Button:
	var button := Button.new()
	button.text = text
	if not node_name.is_empty():
		button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 48
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button


func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CardPanel"
	parent.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	return content


func _icon(id: String, width: int = 24) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s.svg" % id)
	icon.custom_minimum_size = Vector2(width, width)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _resource_chip(parent: Node, id: String) -> void:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	chip.custom_minimum_size.x = 145
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.tooltip_text = tr("resource." + id)
	parent.add_child(chip)
	chip.add_child(_icon(id))
	var value := _label("", 19)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_child(value)
	_resource_chips[id] = value


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = ThemeBuilder.build()
	canvas.add_child(hud)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 24)
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(margins)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_child(layout)
	var header := _panel(layout)
	var time_row := HBoxContainer.new()
	header.add_child(time_row)
	_season_icon = TextureRect.new()
	_season_icon.custom_minimum_size = Vector2(30, 30)
	_season_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_season_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	time_row.add_child(_season_icon)
	_time_label = _label("", 26)
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(_time_label)
	_run_label = _label("", 18, true)
	_run_label.custom_minimum_size.x = 250
	_run_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_row.add_child(_run_label)
	for button: Button in [_button(tr("action.history"), open_turn_history, "TurnHistory"), _button(tr("action.pause"), open_pause, "Pause")]:
		button.theme_type_variation = "QuietButton"
		time_row.add_child(button)
	var resources_row := HBoxContainer.new()
	resources_row.add_theme_constant_override("separation", 18)
	header.add_child(resources_row)
	_resources_label = _label("", 22)
	_resources_label.hide()
	resources_row.add_child(_resources_label)
	for id: String in ["labor", "food", "wood", "people"]:
		_resource_chip(resources_row, id)
	resources_row.add_child(_icon("water"))
	_water_label = _label("", 18, true)
	_water_label.custom_minimum_size.x = 340
	resources_row.add_child(_water_label)
	var survival_row := HBoxContainer.new()
	header.add_child(survival_row)
	survival_row.add_child(_icon("hall", 22))
	_survival_help = _label("", 18)
	_survival_help.name = "PrimaryObjective"
	_survival_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	survival_row.add_child(_survival_help)
	_survival_progress = ProgressBar.new()
	_survival_progress.name = "SurvivalProgress"
	_survival_progress.custom_minimum_size = Vector2(170, 10)
	_survival_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_survival_progress.show_percentage = false
	survival_row.add_child(_survival_progress)
	_condition_icon = _icon("stable", 22)
	survival_row.add_child(_condition_icon)
	_condition_label = _label("", 18, true)
	_condition_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	survival_row.add_child(_condition_label)
	var turn_track := HBoxContainer.new()
	turn_track.add_theme_constant_override("separation", 6)
	header.add_child(turn_track)
	for _turn: int in range(C.TURNS_PER_YEAR):
		var pip := ColorRect.new()
		pip.custom_minimum_size.y = 3
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		turn_track.add_child(pip)
		_turn_pips.append(pip)
	_save_label = _label("", 16, true)
	layout.add_child(_save_label)
	var middle := HBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle)
	var board_space := Control.new()
	board_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(board_space)
	var side_column := VBoxContainer.new()
	side_column.custom_minimum_size.x = 400
	middle.add_child(side_column)
	var advice := _panel(side_column)
	_advisor_panel = advice.get_parent() as PanelContainer
	_advisor_panel.name = "VillageAdvisor"
	var advice_heading := HBoxContainer.new()
	advice.add_child(advice_heading)
	_advisor_icon = _icon("hall", 28)
	advice_heading.add_child(_advisor_icon)
	_advisor_timing = _label("", 17)
	_advisor_timing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advice_heading.add_child(_advisor_timing)
	_advisor_text = _label("", 19)
	advice.add_child(_advisor_text)
	_advisor_button = _button("", _act_on_advice, "AdvisorAction")
	_advisor_button.theme_type_variation = "QuietButton"
	_advisor_button.custom_minimum_size.y = 38
	advice.add_child(_advisor_button)
	var side_scroll := ScrollContainer.new()
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_column.add_child(side_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 380
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(sidebar)
	var objective := _panel(sidebar)
	_goal_panel = objective.get_parent()
	var goal_heading := HBoxContainer.new()
	objective.add_child(goal_heading)
	goal_heading.add_child(_icon("goal"))
	var goal_title := _label(tr("goal.title"), 22)
	goal_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	goal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_heading.add_child(goal_title)
	_goal_label = _label("", 18)
	objective.add_child(_goal_label)
	_goal_bars = VBoxContainer.new()
	_goal_bars.add_theme_constant_override("separation", 6)
	objective.add_child(_goal_bars)
	var latest := _panel(sidebar)
	_latest_panel = latest.get_parent()
	latest.add_child(_label(tr("history.latest"), 22))
	_latest_result = _label("", 18)
	latest.add_child(_latest_result)
	var inspector := _panel(sidebar)
	_tile_title = _label("", 24)
	inspector.add_child(_tile_title)
	_tile_details = _label()
	inspector.add_child(_tile_details)
	_tile_note = _label("", 18, true)
	inspector.add_child(_tile_note)
	var preview_panel := _panel(sidebar)
	preview_panel.add_child(_label(tr("preview.title"), 24))
	_preview_label = _label()
	preview_panel.add_child(_preview_label)
	_preview_button = _button(tr("action.preview"), toggle_preview, "Preview")
	_preview_button.toggle_mode = true
	preview_panel.add_child(_preview_button)
	_preview_legend = _label(tr("preview.legend"), 18, true)
	_preview_legend.name = "PreviewLegend"
	preview_panel.add_child(_preview_legend)
	# The primary objective and highest priority advice stay outside this scroll.
	sidebar.move_child(inspector.get_parent(), 0)
	sidebar.move_child(preview_panel.get_parent(), 1)
	sidebar.add_child(_label(tr("help.controls"), 18, true))
	_status_label = _label("", 18, true)
	layout.add_child(_status_label)
	var toolbar := PanelContainer.new()
	toolbar.theme_type_variation = "CardPanel"
	layout.add_child(toolbar)
	var toolbar_row := HBoxContainer.new()
	toolbar.add_child(toolbar_row)
	_commands_grid = GridContainer.new()
	var commands_grid: GridContainer = _commands_grid
	commands_grid.columns = 7
	commands_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands_grid.add_theme_constant_override("h_separation", 6)
	commands_grid.add_theme_constant_override("v_separation", 6)
	toolbar_row.add_child(commands_grid)
	for index: int in range(COMMANDS.size()):
		var id: String = COMMANDS[index]
		var button := _button("", select_command.bind(id), "Command_" + id)
		button.theme_type_variation = "CommandButton"
		button.custom_minimum_size = Vector2(150, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		button.icon = load("res://assets/icons/%s.svg" % id)
		button.add_theme_constant_override("icon_max_width", 22)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		_command_buttons[id] = button
		commands_grid.add_child(button)
	var turn_box := VBoxContainer.new()
	turn_box.custom_minimum_size.x = 220
	turn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar_row.add_child(turn_box)
	var undo_row := HBoxContainer.new()
	turn_box.add_child(undo_row)
	_undo_button = _button(tr("action.undo"), undo_command, "Undo")
	_undo_button.theme_type_variation = "QuietButton"
	_undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_row.add_child(_undo_button)
	_redo_button = _button(tr("action.redo"), redo_command, "Redo")
	_redo_button.theme_type_variation = "QuietButton"
	_redo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_redo_button.tooltip_text = tr("help.redo")
	undo_row.add_child(_redo_button)
	_end_button = _button(tr("action.end_turn"), request_end_turn, "EndTurn")
	_end_button.theme_type_variation = "PrimaryButton"
	_end_button.icon = preload("res://assets/icons/next.svg")
	_end_button.add_theme_constant_override("icon_max_width", 26)
	turn_box.add_child(_end_button)


func refresh_state() -> void:
	var state: GameState = session.state
	_turn_feedback_active = false
	_feedback.clear()
	_atmosphere.set_rain(state.is_rain())
	_season_icon.texture = load("res://assets/icons/%s.svg" % ("rain" if state.is_rain() else "sun"))
	for index: int in range(_turn_pips.size()):
		_turn_pips[index].color = Color(_colors.accent if index == state.turn - 1 else (_colors.success if index < state.turn - 1 else _colors.border))
	board.set_state(state)
	board.set_labels_visible(show_levels)
	prediction = GameFlow.preview(state) if state.phase == C.Phase.PLANNING else {}
	harvest_projection = {}
	_goal_preview_achieved = false
	_predicted_outcome = C.Outcome.NONE
	harvest_prediction.clear()
	if not prediction.is_empty():
		var predicted: GameState = prediction["state"]
		_predicted_outcome = predicted.outcome
		if state.turn == C.TURNS_PER_YEAR and _predicted_outcome == C.Outcome.NONE:
			var harvested: GameState = predicted.duplicate_state()
			var available_food: int = harvested.food
			var food_needed: int = harvested.population * maxi(0, roundi(float(harvested.mod("food_per_person"))))
			Harvest.do_harvest(harvested)
			_goal_preview_achieved = state.goal_achieved_year == 0 and harvested.goal_achieved_year > 0
			harvest_prediction = harvested.harvest_report.duplicate(true)
			harvest_projection = harvest_prediction.duplicate(true)
			harvest_projection["available_food"] = available_food + int(harvest_projection["paddy_food"])
			harvest_projection["food_needed"] = food_needed
			harvest_projection["capacity"] = harvested.capacity()
			_predicted_outcome = harvested.outcome
	board.set_preview(prediction, preview_enabled)
	board.hover(hovered_coord)
	_targets.clear()
	for index: int in range(COMMANDS.size()):
		var id: String = COMMANDS[index]
		var button: Button = _command_buttons[id]
		var unlock: String = String(CommandRules.DEFS[id].get("unlock", ""))
		button.visible = (unlock.is_empty() or float(state.mod(unlock)) > 0.0) and (id != "brace_house" or state.has_bracing())
		var targets: Array[Vector2i] = valid_targets(id)
		_targets[id] = targets
		button.disabled = targets.is_empty()
		var cost: Vector2i = CommandRules.cost(state, Command.new(id))
		button.text = "%s  %s\n%s" % [KEY_LABELS[index], tr("cmd.%s.name" % id), tr("hud.command_cost") % [cost.x, cost.y]]
		button.tooltip_text = tr("cmd.%s.desc" % id)
		if button.disabled:
			button.tooltip_text += "\n" + tr(_unavailable_reason(id))
		button.set_pressed_no_signal(command_mode == id)
	var visible_commands: int = 0
	for button: Button in _command_buttons.values():
		if button.visible:
			visible_commands += 1
	_commands_grid.columns = 8 if visible_commands > 14 else 7
	for button: Button in _command_buttons.values():
		button.custom_minimum_size.x = 128 if visible_commands > 14 else 150
		button.add_theme_font_size_override("font_size", 16 if visible_commands > 14 else 18)
	_time_label.text = tr("hud.time") % [state.year, state.target_years(), tr("season.rain" if state.is_rain() else "season.dry"), state.turn, C.TURNS_PER_YEAR]
	_run_label.text = tr("run_mode." + state.run_mode + ".name") + "\n" + _difficulty_caption()
	_run_label.tooltip_text = tr("ruleset." + state.ruleset + ".name") if state.ruleset != "legacy" else ""
	_survival_help.text = tr("help.survive_years") % state.target_years()
	_resources_label.text = tr("hud.resources") % [state.labor, state.labor_max, state.food, state.wood, state.population, state.capacity()]
	_resource_chips["labor"].text = tr("resource.labor") + " %d/%d" % [state.labor, state.labor_max]
	_resource_chips["food"].text = tr("resource.food") + " %d" % state.food
	_resource_chips["wood"].text = tr("resource.wood") + " %d" % state.wood
	_resource_chips["people"].text = tr("resource.people") + " %d/%d" % [state.population, state.capacity()]
	_resource_chips["people"].get_parent().tooltip_text = tr("resource.housing_capacity")
	_survival_progress.max_value = state.target_years() * C.TURNS_PER_YEAR
	_survival_progress.value = (state.year - 1) * C.TURNS_PER_YEAR + state.turn - 1
	if state.phase == C.Phase.HARVEST or state.outcome == C.Outcome.WIN:
		_survival_progress.value += 1
	_survival_progress.tooltip_text = tr("survival.progress") % [int(_survival_progress.value), int(_survival_progress.max_value)]
	_condition_icon.visible = Progress.enabled(state)
	_condition_label.visible = Progress.enabled(state)
	if Progress.enabled(state):
		var condition_id: String = Progress.condition_key(state).trim_prefix("settlement.")
		_condition_icon.texture = load("res://assets/icons/%s.svg" % condition_id)
		_condition_label.text = tr("settlement." + condition_id)
		_condition_label.tooltip_text = tr("settlement.explanation")
	_water_label.text = tr("hud.water") % [state.current_inflow(), state.forecast_min, state.forecast_max]
	_undo_button.disabled = state.phase != C.Phase.PLANNING or state.undo.is_empty()
	_redo_button.disabled = state.phase != C.Phase.PLANNING or state.redo.is_empty()
	_end_button.disabled = state.phase != C.Phase.PLANNING
	_preview_button.set_pressed_no_signal(preview_enabled)
	_refresh_save_status()
	_update_preview_text()
	_update_targets()
	_update_inspector()
	_update_command_status()
	_refresh_turn_result()
	_refresh_village_goal()
	_refresh_advisor()


func _difficulty_caption() -> String:
	var state: GameState = session.state
	var multiplier: float = 1.0 + state.difficulty * float(DataDB.balance()["scoring"]["difficulty_step"])
	return tr("difficulty.run") % [state.difficulty, multiplier]


func _refresh_village_goal() -> void:
	var state: GameState = session.state
	_goal_panel.visible = state.village_goal != "none"
	_goal_label.text = ""
	for child: Node in _goal_bars.get_children():
		_goal_bars.remove_child(child)
		child.queue_free()
	if state.village_goal == "none":
		return
	var progress: Dictionary = RunGoals.progress(state)
	var lines := PackedStringArray([tr("goal." + state.village_goal + ".name")])
	if progress["achieved"]:
		lines.append(tr("goal.completed") % [int(progress["achieved_year"]), int(progress["score"])])
	else:
		lines.append(tr("goal.progress_population") % [int(progress["population"]), int(progress["required_population"])])
		if int(progress["required_forests"]) > 0:
			lines.append(tr("goal.progress_forests") % [int(progress["forests"]), int(progress["required_forests"])])
		if int(progress["required_paddy_food"]) > 0:
			lines.append(tr("goal.progress_rice") % [int(progress["paddy_food"]), int(progress["required_paddy_food"])])
		lines.append(tr("goal.harvest_check"))
		lines.append(tr("goal.reward") % int(progress["score"]))
	_goal_label.text = "\n".join(lines)
	if not progress["achieved"]:
		_goal_progress_bar("people", int(progress["population"]), int(progress["required_population"]))
		if int(progress["required_forests"]) > 0:
			_goal_progress_bar("forest", int(progress["forests"]), int(progress["required_forests"]))
		if int(progress["required_paddy_food"]) > 0:
			_goal_progress_bar("paddy", int(progress["paddy_food"]), int(progress["required_paddy_food"]))


func _goal_progress_bar(icon: String, current: int, required: int) -> void:
	var row := HBoxContainer.new()
	_goal_bars.add_child(row)
	row.add_child(_icon(icon, 20))
	var progress := ProgressBar.new()
	progress.max_value = maxi(1, required)
	progress.value = current
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.tooltip_text = "%d / %d" % [current, required]
	row.add_child(progress)
	var count := _label("%d/%d" % [current, required], 16, true)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(count)


func _refresh_advisor() -> void:
	_advisor = Advisor.describe(session.state, prediction, harvest_projection)
	_advisor_icon.texture = load("res://assets/icons/%s.svg" % _advisor["icon"])
	var severity: String = _advisor["severity"]
	var tint: Color = Color(_colors.danger if severity in ["critical", "danger"] else (_colors.accent if severity == "prepare" else _colors.success))
	_advisor_panel.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(_colors.panel_raised), 12, tint))
	_advisor_timing.text = tr("advisor.safe_heading" if severity == "safe" else "advisor." + severity) + " · " + tr(_advisor["timing"])
	_advisor_timing.add_theme_color_override("font_color", tint)
	_advisor_text.text = tr(_advisor["key"])
	var values: Array = _advisor["values"]
	if not values.is_empty():
		_advisor_text.text = _advisor_text.text % values
	_advisor_command = ""
	_advisor_coord = BoardView.NO_COORD
	_advisor_review = false
	var action: String = _advisor["action"]
	if action == "focus":
		_advisor_coord = _advisor["coord"]
		_advisor_button.text = tr("advisor.focus")
	else:
		for id: String in _advisor["commands"]:
			var productive_now: bool = harvest_projection.is_empty() or id != "fish_trap"
			if not productive_now and not prediction.is_empty():
				var predicted: GameState = prediction["state"]
				for coord: Vector2i in _targets.get(id, []):
					if predicted.level_of(predicted.get_tile(coord)) >= 1:
						productive_now = true
						break
			if productive_now and not _targets.get(id, []).is_empty() and _command_buttons[id].visible:
				_advisor_command = id
				break
		if not _advisor_command.is_empty():
			_advisor_button.text = tr("advisor.plan_" + action)
		else:
			for tile: Tile in session.state.tiles:
				var matches: bool = tile.feature == C.Feature.PADDY or tile.building == C.Building.FISH_TRAP
				if action == "housing":
					matches = tile.building in [C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE]
				if matches and action in ["food", "housing"]:
					_advisor_coord = tile.coord
					break
			_advisor_button.text = tr("advisor.inspect_" + action) if action in ["food", "housing"] else ""
			if action in ["food", "housing"] and _advisor_coord == BoardView.NO_COORD:
				_advisor_review = true
				_advisor_button.text = tr("advisor.review")
	_advisor_button.visible = not _advisor_command.is_empty() or _advisor_coord != BoardView.NO_COORD or _advisor_review
	_advisor_button.tooltip_text = tr("advisor.action_help")


func _act_on_advice() -> void:
	if not modal_kind.is_empty():
		return
	if not _advisor_command.is_empty():
		select_command(_advisor_command)
		return
	if _advisor_review:
		_open_modal("advice", tr("advisor.safe_heading"))
		_modal_content.add_child(_label(_advisor_text.text))
		_modal_content.add_child(_label(tr("advisor.no_" + String(_advisor["action"]) + "_action")))
		for line: String in _harvest_preview_lines():
			_modal_content.add_child(_label(line, 18))
		if not session.state.undo.is_empty():
			_add_modal_button(tr("action.undo"), func(): close_modal(); undo_command(), "AdviceUndo")
		_add_modal_button(tr("action.resume"), close_modal, "CloseAdvice", true)
		return
	if _advisor_coord == BoardView.NO_COORD:
		return
	cancel_command()
	hovered_coord = _advisor_coord
	_inspection_focus = _advisor_coord
	_inspection_pointer = get_viewport().get_mouse_position()
	board.select(_advisor_coord)
	board.hover(_advisor_coord)
	var at: Vector3 = Hex.to_world(_advisor_coord)
	camera_rig.position.x = clampf(at.x, -5.0, 5.0)
	camera_rig.position.z = clampf(at.z, -5.0, 5.0)
	_update_inspector()


func _turn_stamp(entry: Dictionary) -> String:
	return tr("history.turn") % [int(entry["year"]), tr("season.rain" if int(entry["season"]) == C.Season.RAIN else "season.dry"), int(entry["turn"])]


func _refresh_turn_result() -> void:
	var entries: Array[Dictionary] = session.turn_history()
	_latest_panel.visible = not entries.is_empty()
	_latest_result.text = ""
	if entries.is_empty():
		return
	var entry: Dictionary = entries[-1]
	var report: Dictionary = entry["report"]
	var lines := PackedStringArray([
		_turn_stamp(entry),
		tr("history.damage_summary") % [report["destroyed"].size(), report["paddies_died"].size()],
		tr("history.production_summary") % [report["paddy_gains"].size(), int(report["fish_food"])],
	])
	if int(entry["outcome"]) != C.Outcome.NONE:
		lines.append(tr("gameover." + C.enum_name(C.Outcome, int(entry["outcome"]))))
	_latest_result.text = "\n".join(lines)


func open_turn_history() -> void:
	if modal_kind not in ["", "pause", "harvest", "game_over"]:
		return
	_history_return = modal_kind
	_open_modal("turn_history", tr("history.title"))
	_modal_content.add_child(_label(tr("history.session_only"), 18, true))
	_history_title = _label("", 24)
	_modal_content.add_child(_history_title)
	var navigation := HBoxContainer.new()
	_modal_content.add_child(navigation)
	_history_previous = _button(tr("history.previous"), _change_history.bind(-1), "PreviousTurnResult")
	_history_next = _button(tr("history.next"), _change_history.bind(1), "NextTurnResult")
	for button: Button in [_history_previous, _history_next]:
		button.focus_mode = Control.FOCUS_ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation.add_child(button)
	_history_scroll = ScrollContainer.new()
	_history_scroll.custom_minimum_size = Vector2(704, 420)
	_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_content.add_child(_history_scroll)
	_history_details = VBoxContainer.new()
	_history_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_scroll.add_child(_history_details)
	history_index = session.turn_history().size() - 1
	_render_turn_history()
	_add_modal_button(tr("action.close"), close_turn_history, "CloseTurnHistory", true)


func close_turn_history() -> void:
	if modal_kind != "turn_history":
		return
	var previous: String = _history_return
	_history_return = ""
	close_modal()
	if previous == "pause":
		open_pause()
	elif previous in ["harvest", "game_over"]:
		_restore_phase_modal()


func _change_history(offset: int) -> void:
	if modal_kind != "turn_history":
		return
	var count: int = session.turn_history().size()
	if count == 0:
		return
	history_index = clampi(history_index + offset, 0, count - 1)
	_render_turn_history()


func _history_coords(coords: Array) -> String:
	var labels := PackedStringArray()
	for coord: Vector2i in coords:
		labels.append("(%d, %d)" % [coord.x, coord.y])
	return tr("history.none") if labels.is_empty() else ", ".join(labels)


func _render_turn_history() -> void:
	for child: Node in _history_details.get_children():
		_history_details.remove_child(child)
		child.queue_free()
	_history_scroll.scroll_vertical = 0
	var entries: Array[Dictionary] = session.turn_history()
	_history_previous.disabled = history_index <= 0
	_history_next.disabled = history_index < 0 or history_index >= entries.size() - 1
	if entries.is_empty():
		_history_title.text = tr("history.empty")
		_history_details.add_child(_label(tr("history.empty_hint")))
		return
	var entry: Dictionary = entries[history_index]
	var report: Dictionary = entry["report"]
	_history_title.text = _turn_stamp(entry)
	_history_details.add_child(_label(tr("history.inflow") % float(report["inflow"])))
	_history_details.add_child(_label(tr("history.hall_wet" if report["hall_wet"] else "history.hall_dry")))
	_history_details.add_child(_label(tr("history.buildings") % report["destroyed"].size()))
	for item: Dictionary in report["destroyed"]:
		var coord: Vector2i = item["coord"]
		var building: String = tr("building." + C.enum_name(C.Building, int(item["building"])))
		_history_details.add_child(_label(tr("history.destroyed_item") % [building, coord.x, coord.y], 18, true))
	_history_details.add_child(_label(tr("history.paddies_died") % [report["paddies_died"].size(), _history_coords(report["paddies_died"])]))
	_history_details.add_child(_label(tr("history.paddy_gains") % [report["paddy_gains"].size(), _history_coords(report["paddy_gains"])]))
	if not report["paddy_gains"].is_empty():
		_history_details.add_child(_label(tr("history.yield_note"), 18, true))
	_history_details.add_child(_label(tr("history.fish") % int(report["fish_food"])))
	for entry_result: Dictionary in report.get("brace_results", []):
		var failed: bool = int(entry_result["level"]) >= int(entry_result["protected_threshold"])
		var key: String = "feedback.brace_failed" if failed else ("feedback.brace_held" if bool(entry_result["prevented_loss"]) else "feedback.brace_expired")
		var coord: Vector2i = entry_result["coord"]
		_history_details.add_child(_label("(%d, %d) · %s" % [coord.x, coord.y, tr(key)]))
	for moisture: Dictionary in report.get("moisture_changes", []):
		var coord: Vector2i = moisture["coord"]
		_history_details.add_child(_label(tr("history.moisture") % [coord.x, coord.y, int(moisture["before"]), int(moisture["after"])], 18, true))
		if int(moisture["yield_from_moisture"]) > 0:
			_history_details.add_child(_label(tr("feedback.moisture_yield"), 18))
	if float(report["dry_paddy_water_used"]) > 0.0:
		_history_details.add_child(_label(tr("history.irrigation") % float(report["dry_paddy_water_used"])))
	if not entry["harvest"].is_empty():
		_history_details.add_child(_label(tr("summary.title") % int(entry["year"]), 24))
		for key: String in ["paddy_food", "eaten", "left_hunger", "left_housing", "born", "spoiled", "food_after", "population_after"]:
			_history_details.add_child(_label(tr("summary." + key) % int(entry["harvest"][key])))
	if int(entry["outcome"]) != C.Outcome.NONE:
		_history_details.add_child(_label(tr("gameover." + C.enum_name(C.Outcome, int(entry["outcome"]))), 24))


func valid_targets(id: String) -> Array[Vector2i]:
	if session.state.phase != C.Phase.PLANNING:
		return []
	if id != "waterwheel":
		return CommandRules.valid_targets(session.state, id)
	var result: Array[Vector2i] = []
	for direction: int in range(6):
		for coord: Vector2i in CommandRules.valid_targets(session.state, id, direction):
			if not result.has(coord):
				result.append(coord)
	return result


func _unavailable_reason(id: String) -> String:
	var state: GameState = session.state
	if state.phase != C.Phase.PLANNING:
		return "err.phase"
	if bool(CommandRules.DEFS[id].get("dry_only", false)) and state.is_rain():
		return "err.season"
	var cost: Vector2i = CommandRules.cost(state, Command.new(id))
	if state.labor < cost.x:
		return "err.labor"
	if state.wood < cost.y:
		return "err.wood"
	return "err.target"


func select_command(id: String) -> void:
	if not modal_kind.is_empty() or session.state.phase != C.Phase.PLANNING:
		return
	if not _command_buttons.has(id) or not _command_buttons[id].visible:
		return
	if _command_buttons[id].disabled:
		_status_label.text = "%s: %s" % [tr("cmd.%s.name" % id), tr(_unavailable_reason(id))]
		return
	command_mode = id
	wheel_origin = BoardView.NO_COORD
	for key: String in _command_buttons:
		_command_buttons[key].set_pressed_no_signal(key == id)
	_update_targets()
	_update_inspector()
	_update_command_status()


func cancel_command() -> void:
	command_mode = ""
	wheel_origin = BoardView.NO_COORD
	for button: Button in _command_buttons.values():
		button.set_pressed_no_signal(false)
	board.clear_targets()
	_update_inspector()
	_update_command_status()


func apply_at(coord: Vector2i) -> void:
	if not modal_kind.is_empty() or session.state.phase != C.Phase.PLANNING:
		return
	var state: GameState = session.state
	var tile: Tile = state.get_tile(coord)
	if tile == null:
		return
	var id: String = command_mode
	var origin: Vector2i = coord
	var parameter: int = -1
	if id.is_empty():
		if tile.building != C.Building.GATE:
			board.select(coord)
			return
		id = "toggle_gate"
	elif id == "waterwheel":
		if wheel_origin == BoardView.NO_COORD:
			if not _targets.get(id, []).has(coord):
				_status_label.text = tr("err.target")
				return
			wheel_origin = coord
			_update_targets()
			_update_command_status()
			return
		origin = wheel_origin
		for direction: int in range(6):
			var neighbor: Tile = state.neighbor_in_dir(state.get_tile(origin), direction)
			if neighbor != null and neighbor.coord == coord:
				parameter = direction
				break
		if parameter < 0:
			_status_label.text = tr("err.param")
			return
	var previous_elevation: int = state.get_tile(origin).elevation
	var previous_labor: int = state.labor
	var previous_wood: int = state.wood
	var error: String = session.apply(Command.new(id, origin, parameter))
	if not error.is_empty():
		_status_label.text = tr(error)
		return
	wheel_origin = BoardView.NO_COORD
	hovered_coord = coord
	refresh_state()
	board.select(origin)
	board.show_command_activity(id, origin)
	_show_command_feedback(id, origin, previous_elevation, previous_labor, previous_wood)
	if not command_mode.is_empty() and _targets.get(command_mode, []).is_empty():
		_update_command_status()
	else:
		_status_label.text = tr("msg.command_done") % tr("cmd.%s.name" % id)


func _feedback_position(coord: Vector2i) -> Vector3:
	var tile: Tile = session.state.get_tile(coord)
	var at: Vector3 = Hex.to_world(coord)
	at.y = board._surface_y(tile) + 0.08
	return at


func _show_command_feedback(id: String, coord: Vector2i, elevation_before: int, labor_before: int, wood_before: int) -> void:
	var state: GameState = session.state
	var title: String = tr("cmd.%s.name" % id)
	var height_change: int = state.get_tile(coord).elevation - elevation_before
	if height_change != 0:
		title += " · " + tr("feedback.height") % height_change
	var changes := PackedStringArray()
	if state.labor != labor_before:
		changes.append(tr("feedback.labor") % (state.labor - labor_before))
	if state.wood != wood_before:
		changes.append(tr("feedback.wood") % (state.wood - wood_before))
	var text: String = title if changes.is_empty() else title + "\n" + " · ".join(changes)
	_feedback.show_marker(_feedback_position(coord), text, Color(_colors.accent))


func _show_turn_feedback(report: TurnReport) -> void:
	# Read the committed report. Never replay a preview or re-evaluate production.
	var events: Dictionary = {}
	for item: Dictionary in report.destroyed:
		var name: String = tr("building." + C.enum_name(C.Building, int(item["building"])))
		_add_feedback_event(events, item["coord"], tr("feedback.destroyed") % name, true)
	for coord: Vector2i in report.paddies_died:
		_add_feedback_event(events, coord, tr("feedback.rice_lost"), true)
	for entry: Dictionary in report.brace_results:
		var failed: bool = int(entry["level"]) >= int(entry["protected_threshold"])
		var key: String = "feedback.brace_failed" if failed else ("feedback.brace_held" if bool(entry["prevented_loss"]) else "feedback.brace_expired")
		_add_feedback_event(events, entry["coord"], tr(key), failed)
	var moisture_yields: Dictionary = {}
	for moisture: Dictionary in report.moisture_changes:
		if int(moisture["yield_from_moisture"]) > 0:
			moisture_yields[moisture["coord"]] = true
	for coord: Vector2i in report.paddy_gains:
		_add_feedback_event(events, coord, tr("feedback.moisture_yield" if moisture_yields.has(coord) else "feedback.rice_gain"))
	var fish: Dictionary = BoardView.preview_fish_food_by_tile(session.state, report)
	for coord: Vector2i in fish:
		_add_feedback_event(events, coord, tr("feedback.food_gain") % int(fish[coord]))
	var shown: int = 0
	for coord: Vector2i in events:
		if shown >= ActionFeedback.MAX_MARKERS:
			break
		var event: Dictionary = events[coord]
		var danger: bool = event["danger"]
		_feedback.show_marker(_feedback_position(coord), "\n".join(event["lines"]), Color(_colors.danger if danger else _colors.success), "danger" if danger else "success")
		shown += 1
	if shown > 0:
		_turn_feedback_active = true
		board.set_preview({}, false)


func _on_feedback_emptied() -> void:
	if not _turn_feedback_active:
		return
	_turn_feedback_active = false
	board.finish_actual_flow()
	# Restore the current forecast, never the resolved turn's prior preview.
	if session != null and session.state != null and session.state.phase == C.Phase.PLANNING:
		board.set_preview(prediction, preview_enabled)


func _add_feedback_event(events: Dictionary, coord: Vector2i, text: String, danger: bool = false) -> void:
	if session.state.get_tile(coord) == null:
		return
	if not events.has(coord):
		events[coord] = {"lines": PackedStringArray(), "danger": false}
	var lines: PackedStringArray = events[coord]["lines"]
	lines.append(text)
	events[coord]["lines"] = lines
	events[coord]["danger"] = bool(events[coord]["danger"]) or danger


func undo_command() -> void:
	if not modal_kind.is_empty():
		return
	if session.undo():
		wheel_origin = BoardView.NO_COORD
		board.clear_activity()
		refresh_state()


func redo_command() -> void:
	if not modal_kind.is_empty():
		return
	if session.redo():
		wheel_origin = BoardView.NO_COORD
		board.clear_activity()
		refresh_state()


func toggle_preview() -> void:
	if not modal_kind.is_empty():
		return
	_feedback.clear()
	board.finish_actual_flow()
	preview_enabled = not preview_enabled
	_preview_button.set_pressed_no_signal(preview_enabled)
	board.set_preview(prediction, preview_enabled)
	_update_preview_text()
	_update_inspector()


func _update_command_status() -> void:
	if wheel_origin != BoardView.NO_COORD:
		_status_label.text = tr("tile.wheel_direction")
	elif command_mode.is_empty():
		_status_label.text = tr("help.survive_years") % session.state.target_years()
	elif _targets.get(command_mode, []).is_empty():
		_status_label.text = "%s: %s" % [tr("cmd.%s.name" % command_mode), tr(_unavailable_reason(command_mode))]
	else:
		_status_label.text = tr("hud.selected") % tr("cmd.%s.name" % command_mode)


func _update_targets() -> void:
	if command_mode.is_empty():
		board.clear_targets()
		return
	var targets: Array[Vector2i] = []
	if wheel_origin == BoardView.NO_COORD:
		targets.assign(_targets.get(command_mode, []))
	else:
		var tile: Tile = session.state.get_tile(wheel_origin)
		for direction: int in range(6):
			if CommandRules.check(session.state, Command.new("waterwheel", wheel_origin, direction)).is_empty():
				var neighbor: Tile = session.state.neighbor_in_dir(tile, direction)
				if neighbor != null:
					targets.append(neighbor.coord)
	var invalid: Vector2i = BoardView.NO_COORD
	if hovered_coord != BoardView.NO_COORD and not targets.has(hovered_coord):
		invalid = hovered_coord
	board.set_targets(targets, invalid)


func _update_inspector() -> void:
	var state: GameState = session.state
	var tile: Tile = state.get_tile(hovered_coord)
	if tile == null:
		_tile_title.text = tr("tile.none")
		_tile_details.text = ""
		_tile_note.text = ""
		return
	var kind: String = tr("tile.land")
	if tile.is_source:
		kind = tr("tile.source")
	elif tile.is_sea:
		kind = tr("tile.sea")
	elif tile.building != C.Building.NONE:
		kind = tr("building." + C.enum_name(C.Building, tile.building))
	elif tile.feature != C.Feature.NONE:
		kind = tr("feature." + C.enum_name(C.Feature, tile.feature))
	elif tile.is_river:
		kind = tr("tile.river")
	_tile_title.text = tr("tile.coord") % [kind, tile.q, tile.r]
	_tile_details.text = tr("tile.details") % [tile.elevation, tile.water, tr("level.%d" % state.level_of(tile))]
	if preview_enabled and not prediction.is_empty():
		var predicted: GameState = prediction["state"]
		var after: Tile = predicted.get_tile(tile.coord)
		_tile_details.text += "\n" + tr("tile.predicted") % [after.water, tr("level.%d" % predicted.level_of(after))]
	_tile_note.text = ""
	if tile.feature == C.Feature.PADDY:
		if tile.paddy_dead:
			_tile_note.text = tr("tile.paddy_dead")
		else:
			_tile_note.text = tr("tile.paddy") % [tile.paddy_yield, tile.paddy_rain_turns]
		if state.has_moisture():
			_tile_note.text += "\n" + tr("tile.moisture") % [tile.soil_moisture, 2]
			_tile_note.text += "\n" + tr("tile.moisture_hint")
	elif tile.building == C.Building.GATE:
		_tile_note.text = tr("tile.gate_open" if tile.gate_open else "tile.gate_closed")
		if command_mode.is_empty() and state.phase == C.Phase.PLANNING:
			_tile_note.text += "\n" + tr("tile.gate_hint")
	elif tile.building == C.Building.WATERWHEEL:
		var intake: Tile = state.neighbor_in_dir(tile, tile.wheel_dir)
		if intake != null:
			_tile_note.text = tr("tile.wheel_intake") % [intake.q, intake.r]
	if state.has_bracing() and tile.brace_turns > 0:
		_tile_note.text += ("\n" if not _tile_note.text.is_empty() else "") + tr("tile.braced")
	if Progress.enabled(state) and tile.building != C.Building.NONE:
		_tile_note.text += ("\n" if not _tile_note.text.is_empty() else "") + tr("settlement.building_age") % Progress.building_age(state, tile)
		_tile_note.text += "\n" + tr("settlement.building_stage") % tr("settlement.stage.%d" % Progress.building_stage(state, tile))
	for line: String in _tile_preview_lines(tile):
		_tile_note.text += ("\n" if not _tile_note.text.is_empty() else "") + line
	if not command_mode.is_empty():
		var origin: Vector2i = wheel_origin if wheel_origin != BoardView.NO_COORD else tile.coord
		var parameter: int = -1
		if command_mode == "waterwheel":
			if wheel_origin == BoardView.NO_COORD:
				if _targets.get(command_mode, []).has(tile.coord):
					return
			else:
				for direction: int in range(6):
					var neighbor: Tile = state.neighbor_in_dir(state.get_tile(origin), direction)
					if neighbor != null and neighbor.coord == tile.coord:
						parameter = direction
		var error: String = CommandRules.check(state, Command.new(command_mode, origin, parameter))
		if not error.is_empty():
			_tile_note.text += ("\n" if not _tile_note.text.is_empty() else "") + tr(error)


func _tile_preview_lines(tile: Tile) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if not preview_enabled or prediction.is_empty():
		return lines
	var predicted: GameState = prediction["state"]
	var report: TurnReport = prediction["report"]
	var moisture_production: bool = false
	for moisture: Dictionary in report.moisture_changes:
		if moisture["coord"] == tile.coord:
			lines.append(tr("tile.moisture_forecast") % [int(moisture["before"]), int(moisture["after"])])
			if int(moisture["yield_from_moisture"]) > 0:
				moisture_production = true
				lines.append(tr("tile.moisture_yield"))
	var braced_threshold: int = -1
	for entry: Dictionary in report.brace_results:
		if entry["coord"] == tile.coord:
			braced_threshold = int(entry["protected_threshold"])
			lines.append(tr("tile.brace_forecast") % braced_threshold)
			if bool(entry["prevented_loss"]):
				lines.append(tr("tile.brace_held_forecast"))
	if tile.building == C.Building.HALL and report.outcome == C.Outcome.LOSE_HALL:
		lines.append(tr("preview.lose_hall"))
		lines.append(_flood_limit_line(predicted, "hall_lose_level"))
	for entry: Dictionary in report.destroyed:
		if entry["coord"] != tile.coord:
			continue
		var building: int = int(entry["building"])
		lines.append(tr("tile.destroyed_forecast") % tr("building." + C.enum_name(C.Building, building)))
		var limits: Dictionary = {
			C.Building.HOUSE: "house_destroy_level",
			C.Building.STILT_HOUSE: "stilt_destroy_level",
			C.Building.GRANARY: "granary_destroy_level",
		}
		if limits.has(building):
			lines.append(_flood_threshold_line(braced_threshold) if braced_threshold >= 0 else _flood_limit_line(predicted, limits[building]))
	if report.paddies_died.has(tile.coord):
		lines.append(tr("tile.paddy_dies"))
		lines.append(_flood_limit_line(predicted, "paddy_death_level"))
	# Damage is completed even on a losing flood, but production is skipped.
	if report.outcome != C.Outcome.LOSE_HALL:
		if report.paddy_gains.has(tile.coord) and not moisture_production:
			lines.append(tr("tile.paddy_gain"))
		var fish: int = int(BoardView.preview_fish_food_by_tile(predicted, report).get(tile.coord, 0))
		if fish > 0:
			lines.append(tr("tile.fish_gain") % fish)
	return lines


func _flood_limit_line(predicted: GameState, key: String) -> String:
	return _flood_threshold_line(roundi(float(predicted.mods[key])))


func _flood_threshold_line(threshold: int) -> String:
	if threshold >= 0 and threshold <= 3:
		return tr("tile.flood_limit") % [threshold, tr("level.%d" % threshold)]
	return tr("tile.flood_limit_number") % threshold


func _update_preview_text() -> void:
	_preview_legend.visible = preview_enabled and not prediction.is_empty()
	if not preview_enabled:
		_preview_label.text = tr("preview.disabled")
		return
	if prediction.is_empty():
		_preview_label.text = ""
		return
	var report: TurnReport = prediction["report"]
	var lines: PackedStringArray = PackedStringArray()
	if _predicted_outcome == C.Outcome.LOSE_HALL:
		lines.append(tr("preview.lose_hall"))
	elif _predicted_outcome == C.Outcome.LOSE_POPULATION:
		lines.append(tr("preview.lose_population"))
	if not report.destroyed.is_empty():
		lines.append(tr("preview.destroyed") % report.destroyed.size())
	if not report.paddies_died.is_empty():
		lines.append(tr("preview.paddies_died") % report.paddies_died.size())
	if not report.paddy_gains.is_empty():
		lines.append(tr("preview.paddy_gains") % report.paddy_gains.size())
	if report.fish_food > 0:
		lines.append(tr("preview.fish") % report.fish_food)
	lines.append_array(_harvest_preview_lines())
	if lines.is_empty():
		lines.append(tr("preview.safe"))
	_preview_label.text = "\n".join(lines)


func _harvest_preview_lines() -> PackedStringArray:
	if harvest_projection.is_empty():
		return PackedStringArray()
	var report: Dictionary = harvest_projection
	var lines := PackedStringArray([
		tr("preview.harvest_title"),
		tr("preview.harvest_paddy") % int(report["paddy_food"]),
		tr("preview.harvest_food") % [int(report["available_food"]), int(report["food_needed"]), int(report["eaten"])],
		tr("preview.harvest_migration") % [int(report["left_hunger"]), int(report["left_housing"])],
		tr("preview.harvest_growth") % [int(report["born"]), int(report["spoiled"])],
		tr("preview.harvest_food_after") % int(report["food_after"]),
		tr("preview.harvest_people") % [int(report["population_after"]), int(report["capacity"])],
	])
	if _goal_preview_achieved:
		lines.append(tr("goal.preview_complete") % int(RunGoals.progress(session.state)["score"]))
	return lines


func _refresh_save_status() -> void:
	_save_label.add_theme_color_override("font_color", Color(_colors.danger if not session.last_save_error.is_empty() or not _preferences_error.is_empty() else _colors.muted))
	if not session.last_save_error.is_empty():
		_save_label.text = tr(session.last_save_error)
	elif not _preferences_error.is_empty():
		_save_label.text = tr(_preferences_error)
	else:
		_save_label.text = tr("msg.saved")


func request_end_turn() -> void:
	if not modal_kind.is_empty() or session.state.phase != C.Phase.PLANNING:
		return
	if _predicted_outcome in [C.Outcome.LOSE_HALL, C.Outcome.LOSE_POPULATION]:
		_open_modal("confirm_loss", tr("preview.title"))
		_modal_content.add_child(_label(tr("confirm.loss")))
		if _predicted_outcome == C.Outcome.LOSE_HALL:
			_modal_content.add_child(_label(tr("preview.lose_hall")))
		elif _predicted_outcome == C.Outcome.LOSE_POPULATION:
			_modal_content.add_child(_label(tr("preview.lose_population")))
		for line: String in _harvest_preview_lines():
			_modal_content.add_child(_label(line))
		_add_modal_button(tr("action.confirm"), _confirm_end_turn, "ConfirmEndTurn")
		_add_modal_button(tr("action.cancel"), close_modal, "CancelEndTurn", true)
	elif confirm_unused_labor and session.state.is_rain() and session.state.labor >= 2:
		_open_modal("confirm_labor", tr("action.end_turn"))
		_modal_content.add_child(_label(tr("confirm.unused_labor") % session.state.labor))
		_skip_confirmation = CheckBox.new()
		_skip_confirmation.text = tr("confirm.dont_ask")
		_modal_content.add_child(_skip_confirmation)
		_add_modal_button(tr("action.confirm"), _confirm_end_turn, "ConfirmEndTurn")
		_add_modal_button(tr("action.cancel"), close_modal, "CancelEndTurn", true)
	else:
		_finish_turn()


func _confirm_end_turn() -> void:
	if modal_kind not in ["confirm_loss", "confirm_labor"]:
		return
	if modal_kind == "confirm_labor" and _skip_confirmation.button_pressed:
		confirm_unused_labor = false
		_preferences_error = _save_game_preferences()
	close_modal()
	_finish_turn()


func _finish_turn() -> void:
	var report: TurnReport = session.advance_turn()
	if report == null:
		return
	wheel_origin = BoardView.NO_COORD
	refresh_state()
	board.show_actual_flow(report)
	board.show_turn_activity(report)
	board.show_harvest_activity(session.last_harvest_food_by_tile)
	if session.state.phase == C.Phase.PLANNING:
		_show_turn_feedback(report)
	if session.state.phase == C.Phase.HARVEST:
		_show_harvest()
	elif session.state.phase == C.Phase.GAME_OVER:
		_show_game_over()


func _open_modal(kind: String, title: String) -> void:
	_feedback.clear()
	close_modal()
	modal_kind = kind
	board.set_activity_paused(true)
	_modal = Control.new()
	_modal.name = "GameModal"
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_modal)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.07, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CardPanel"
	panel.custom_minimum_size.x = 740
	center.add_child(panel)
	_modal_content = VBoxContainer.new()
	panel.add_child(_modal_content)
	_modal_content.add_child(_label(title, 32))
	board.clear_hover()


func close_modal() -> void:
	if _modal != null:
		hud.remove_child(_modal)
		_modal.queue_free()
	_modal = null
	_modal_content = null
	_skip_confirmation = null
	modal_kind = ""
	if board != null:
		board.set_activity_paused(false)
		board.hover(hovered_coord)


func _add_modal_button(text: String, callback: Callable, node_name: String = "", preferred: bool = false) -> Button:
	var button: Button = _button(text, callback, node_name)
	if node_name == "ConfirmEndTurn" and modal_kind == "confirm_loss":
		button.theme_type_variation = "DangerButton"
	elif node_name in ["ContinueHarvest", "Restart", "ConfirmEndTurn"]:
		button.theme_type_variation = "PrimaryButton"
	else:
		button.theme_type_variation = "QuietButton"
	button.focus_mode = Control.FOCUS_ALL
	_modal_content.add_child(button)
	if preferred:
		button.grab_focus()
	return button


func _show_harvest() -> void:
	_open_modal("harvest", tr("summary.title") % session.state.year)
	for key: String in ["paddy_food", "eaten", "left_hunger", "left_housing", "born", "spoiled", "food_after", "population_after"]:
		_modal_content.add_child(_label(tr("summary." + key) % int(session.state.harvest_report[key])))
	if session.state.goal_achieved_year == session.state.year and session.state.village_goal != "none":
		_modal_content.add_child(_label(tr("goal." + session.state.village_goal + ".name"), 20))
		_modal_content.add_child(_label(tr("goal.completed") % [session.state.goal_achieved_year, int(RunGoals.progress(session.state)["score"])], 20))
	var caption: String = tr("action.finish") if session.state.outcome != C.Outcome.NONE else tr("action.continue")
	_add_modal_button(caption, continue_harvest, "ContinueHarvest", true)
	_add_modal_button(tr("action.history"), open_turn_history, "HarvestHistory")
	_add_modal_button(tr("action.menu"), _return_menu, "HarvestMenu")


func continue_harvest() -> void:
	if modal_kind != "harvest":
		return
	close_modal()
	if session.continue_year():
		refresh_state()
		if session.state.phase == C.Phase.GAME_OVER:
			_show_game_over()


func _show_game_over() -> void:
	var state: GameState = session.state
	_open_modal("game_over", tr("gameover." + C.enum_name(C.Outcome, state.outcome)))
	_modal_content.add_child(_label(tr("gameover.score") % state.final_score, 28))
	var scoring: Dictionary = DataDB.balance()["scoring"]
	var house_bonus: int = int(scoring["no_houses_lost"]) if state.outcome == C.Outcome.WIN and int(state.stats["houses_lost"]) == 0 else 0
	var hall_bonus: int = int(scoring["hall_dry"]) if state.outcome == C.Outcome.WIN and not bool(state.stats["hall_ever_wet"]) else 0
	_modal_content.add_child(_label(tr("gameover.components") % [state.population * int(scoring["population"]), state.food, house_bonus, hall_bonus, 1.0 + state.difficulty * float(scoring["difficulty_step"])]))
	_modal_content.add_child(_label(tr("run_mode." + state.run_mode + ".name"), 20, true))
	_modal_content.add_child(_label(_difficulty_caption(), 20, true))
	if state.ruleset != "legacy":
		_modal_content.add_child(_label(tr("ruleset." + state.ruleset + ".name"), 18, true))
	if state.village_goal != "none":
		var goal: Dictionary = RunGoals.progress(state)
		_modal_content.add_child(_label(tr("goal." + state.village_goal + ".name"), 22))
		_modal_content.add_child(_label(tr("goal.completed") % [int(goal["achieved_year"]), int(goal["score"])] if goal["achieved"] else tr("goal.unfinished"), 20))
	_modal_content.add_child(_label(tr("gameover.seed") % str(state.seed)))
	_add_modal_button(tr("action.history"), open_turn_history, "GameOverHistory")
	_add_modal_button(tr("action.restart"), _restart, "Restart")
	_add_modal_button(tr("action.menu"), _return_menu, "GameOverMenu", true)


func _restart() -> void:
	var config: Dictionary = {"seed": session.state.seed + 1, "map_type": "plains", "leader": session.state.leader, "difficulty": session.state.difficulty, "run_mode": session.state.run_mode, "village_goal": session.state.village_goal}
	if session.state.ruleset != "legacy":
		config["ruleset"] = session.state.ruleset
	restart_requested.emit(config)


func open_pause() -> void:
	if not modal_kind.is_empty() or session.state.phase != C.Phase.PLANNING:
		return
	_open_modal("pause", tr("pause.title"))
	_modal_content.add_child(_label(tr("pause.seed") % str(session.state.seed)))
	_modal_content.add_child(_label(_difficulty_caption(), 20, true))
	if session.state.ruleset != "legacy":
		_modal_content.add_child(_label(tr("ruleset." + session.state.ruleset + ".name"), 18, true))
	if session.state.has_moisture():
		_modal_content.add_child(_label(tr("pause.moisture_hint"), 18, true))
	_motion_toggle = CheckBox.new()
	_motion_toggle.name = "ReducedMotion"
	_motion_toggle.text = tr("pause.reduced_motion")
	_motion_toggle.tooltip_text = tr("pause.reduced_motion_hint")
	_motion_toggle.set_pressed_no_signal(reduced_motion)
	_motion_toggle.toggled.connect(_on_motion_toggled)
	_modal_content.add_child(_motion_toggle)
	_motion_error = _label("", 18)
	_motion_error.add_theme_color_override("font_color", Color(_colors.danger))
	_motion_error.visible = false
	_modal_content.add_child(_motion_error)
	_add_modal_button(tr("action.resume"), close_modal, "Resume", true)
	_add_modal_button(tr("action.history"), open_turn_history, "PauseHistory")
	if not session.last_save_error.is_empty():
		_modal_content.add_child(_label(tr(session.last_save_error)))
		_add_modal_button(tr("action.retry_save"), _retry_save, "RetrySave")
	_add_modal_button(tr("action.menu"), _return_menu, "PauseMenu")


func _apply_motion_preference() -> void:
	_feedback.set_reduced_motion(reduced_motion)
	_atmosphere.set_reduced_motion(reduced_motion)
	camera_rig.set_reduced_motion(reduced_motion)
	board.set_reduced_motion(reduced_motion)


func _on_motion_toggled(enabled: bool) -> void:
	reduced_motion = enabled
	_apply_motion_preference()
	_preferences_error = _save_game_preferences()
	_refresh_save_status()
	if is_instance_valid(_motion_error):
		_motion_error.text = tr(_preferences_error) if not _preferences_error.is_empty() else ""
		_motion_error.visible = not _preferences_error.is_empty()


func _save_game_preferences() -> String:
	# A successful retry also preserves any other live choice whose earlier
	# settings write failed; game progress remains in its separate checkpoint.
	return GamePreferences.write({
		"confirm_unused_labor": confirm_unused_labor,
		"reduced_motion": reduced_motion,
	}, preferences_path)


func _retry_save() -> void:
	session.checkpoint()
	_refresh_save_status()
	if session.last_save_error.is_empty():
		close_modal()


func _return_menu() -> void:
	_leave_game(func(): menu_requested.emit())


func request_quit() -> void:
	_leave_game(func(): get_tree().quit())


func _leave_game(exit_action: Callable) -> void:
	if session.checkpoint().is_empty():
		exit_action.call()
		return
	_refresh_save_status()
	_open_modal("save_error", tr("msg.save_failed"))
	_modal_content.add_child(_label(tr("msg.unsaved_progress")))
	_add_modal_button(tr("action.retry_save"), _leave_game.bind(exit_action), "RetryLeave")
	_add_modal_button(tr("action.leave_without_save"), exit_action, "LeaveWithoutSave")
	_add_modal_button(tr("action.resume"), func(): close_modal(); _restore_phase_modal(), "ResumeAfterSaveError", true)


func _restore_phase_modal() -> void:
	if session.state.phase == C.Phase.HARVEST:
		_show_harvest()
	elif session.state.phase == C.Phase.GAME_OVER:
		_show_game_over()


func _process(delta: float) -> void:
	if session == null or session.state == null or not modal_kind.is_empty():
		return
	if not get_viewport().gui_get_focus_owner() is LineEdit:
		var horizontal: float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		var vertical: float = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		var pan := Vector2(horizontal, vertical)
		if pan != Vector2.ZERO:
			camera_rig.pan(pan.normalized(), delta)
	var pointer: Vector2 = get_viewport().get_mouse_position()
	var next_coord: Vector2i = BoardView.NO_COORD
	if _inspection_focus != BoardView.NO_COORD and pointer.is_equal_approx(_inspection_pointer):
		# Camera movement must not replace a tile explicitly selected by advice.
		next_coord = _inspection_focus
	else:
		_inspection_focus = BoardView.NO_COORD
		if get_viewport().gui_get_hovered_control() == null:
			var tile: Tile = board.pick(camera_rig.get_camera(), pointer)
			if tile != null:
				next_coord = tile.coord
	if next_coord != hovered_coord:
		hovered_coord = next_coord
		board.hover(hovered_coord)
		_update_targets()
		_update_inspector()


func _input(event: InputEvent) -> void:
	# This sees motion over the HUD too, before GUI controls consume the event.
	if event is InputEventMouseMotion and event.relative != Vector2.ZERO:
		_inspection_focus = BoardView.NO_COORD
	# Holding the key that opens a summary must not accept its next action.
	if not modal_kind.is_empty() and event is InputEventKey and event.pressed and event.echo and event.is_action("ui_accept"):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if session == null or session.state == null:
		return
	if not modal_kind.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_H and modal_kind in ["pause", "harvest", "game_over"]:
				open_turn_history()
			elif event.physical_keycode == KEY_ESCAPE:
				if modal_kind == "turn_history":
					close_turn_history()
				elif modal_kind in ["pause", "confirm_loss", "confirm_labor"]:
					close_modal()
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if event.ctrl_pressed and (key == KEY_Y or (key == KEY_Z and event.shift_pressed)):
			redo_command()
		elif key == KEY_Z and event.ctrl_pressed:
			undo_command()
		elif SHORTCUTS.has(key):
			select_command(SHORTCUTS[key])
		else:
			match key:
				KEY_SPACE, KEY_ENTER: request_end_turn()
				KEY_TAB: toggle_preview()
				KEY_H: open_turn_history()
				KEY_V:
					show_levels = not show_levels
					board.set_labels_visible(show_levels)
				KEY_Q: camera_rig.rotate_step(-1)
				KEY_E: camera_rig.rotate_step(1)
				KEY_ESCAPE:
					if command_mode.is_empty():
						open_pause()
					else:
						cancel_command()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		camera_rig.pan(-event.relative / 100.0, 1.0)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: camera_rig.zoom_step(-1)
			MOUSE_BUTTON_WHEEL_DOWN: camera_rig.zoom_step(1)
			MOUSE_BUTTON_RIGHT: cancel_command()
			MOUSE_BUTTON_LEFT:
				var tile: Tile = board.pick(camera_rig.get_camera(), event.position)
				if tile != null:
					apply_at(tile.coord)
