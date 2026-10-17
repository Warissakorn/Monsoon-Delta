class_name GameScreen
extends Node
## Presentation/controller for a run; GameSession alone owns checkpoints.

signal menu_requested
signal restart_requested(config: Dictionary)

const COMMANDS: Array[String] = [
	"dig", "fill", "paddy", "house", "stilt_house", "raft_house", "gate",
	"reservoir", "fish_trap", "granary", "chop", "plant", "waterwheel", "demolish",
]
const SHORTCUTS: Dictionary = {
	KEY_1: "dig", KEY_2: "fill", KEY_3: "paddy", KEY_4: "house", KEY_5: "stilt_house",
	KEY_6: "raft_house", KEY_7: "gate", KEY_8: "reservoir", KEY_9: "fish_trap",
	KEY_0: "granary", KEY_C: "chop", KEY_P: "plant", KEY_B: "waterwheel", KEY_X: "demolish",
}
const KEY_LABELS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "C", "P", "B", "X"]

var session: GameSession
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
var _modal: Control
var _modal_content: VBoxContainer
var _skip_confirmation: CheckBox
var _time_label: Label
var _resources_label: Label
var _water_label: Label
var _save_label: Label
var _tile_title: Label
var _tile_details: Label
var _tile_note: Label
var _preview_label: Label
var _preview_legend: Label
var _status_label: Label
var _command_buttons: Dictionary = {}
var _targets: Dictionary = {}
var _preview_button: Button
var _undo_button: Button
var _redo_button: Button
var _end_button: Button
var _predicted_outcome: int = C.Outcome.NONE
var _preferences_error: String = ""
var _colors: Dictionary


func _ready() -> void:
	_colors = ThemeBuilder.palette()
	confirm_unused_labor = bool(GamePreferences.read()["confirm_unused_labor"])
	_build_world()
	_build_hud()
	if session == null or session.state == null:
		return
	refresh_state()
	if session.state.phase == C.Phase.HARVEST:
		_show_harvest()
	elif session.state.phase == C.Phase.GAME_OVER:
		_show_game_over()


func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(_colors.background)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d7e4d2")
	environment.ambient_light_energy = 0.4
	world.environment = environment
	add_child(world)
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
	camera_rig.get_camera().h_offset = 1.65


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
	parent.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	return content


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
	_time_label = _label("", 28)
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(_time_label)
	time_row.add_child(_button(tr("action.pause"), open_pause, "Pause"))
	_resources_label = _label()
	header.add_child(_resources_label)
	_water_label = _label("", 20, true)
	header.add_child(_water_label)
	_save_label = _label("", 18)
	_save_label.add_theme_color_override("font_color", Color(_colors.accent))
	layout.add_child(_save_label)
	var middle := HBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle)
	var board_space := Control.new()
	board_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(board_space)
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 340
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(side_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 320
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(sidebar)
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
	sidebar.add_child(_label(tr("help.goal"), 20, true))
	sidebar.add_child(_label(tr("help.controls"), 18, true))
	_status_label = _label("", 20)
	layout.add_child(_status_label)
	var toolbar := PanelContainer.new()
	layout.add_child(toolbar)
	var toolbar_row := HBoxContainer.new()
	toolbar.add_child(toolbar_row)
	var commands_grid := GridContainer.new()
	commands_grid.columns = 7
	commands_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands_grid.add_theme_constant_override("h_separation", 6)
	commands_grid.add_theme_constant_override("v_separation", 6)
	toolbar_row.add_child(commands_grid)
	for index: int in range(COMMANDS.size()):
		var id: String = COMMANDS[index]
		var button := _button("", select_command.bind(id), "Command_" + id)
		button.custom_minimum_size = Vector2(150, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		_command_buttons[id] = button
		commands_grid.add_child(button)
	var turn_box := VBoxContainer.new()
	turn_box.custom_minimum_size.x = 220
	turn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar_row.add_child(turn_box)
	_undo_button = _button(tr("action.undo"), undo_command, "Undo")
	turn_box.add_child(_undo_button)
	_redo_button = _button(tr("action.redo"), redo_command, "Redo")
	_redo_button.tooltip_text = tr("help.redo")
	turn_box.add_child(_redo_button)
	_end_button = _button(tr("action.end_turn"), request_end_turn, "EndTurn")
	turn_box.add_child(_end_button)


func refresh_state() -> void:
	var state: GameState = session.state
	board.set_state(state)
	board.set_labels_visible(show_levels)
	prediction = GameFlow.preview(state) if state.phase == C.Phase.PLANNING else {}
	harvest_projection = {}
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
		button.visible = unlock.is_empty() or float(state.mod(unlock)) > 0.0
		var targets: Array[Vector2i] = valid_targets(id)
		_targets[id] = targets
		button.disabled = targets.is_empty()
		var cost: Vector2i = CommandRules.cost(state, Command.new(id))
		button.text = "%s  %s\n%s" % [KEY_LABELS[index], tr("cmd.%s.name" % id), tr("hud.command_cost") % [cost.x, cost.y]]
		button.tooltip_text = tr("cmd.%s.desc" % id)
		if button.disabled:
			button.tooltip_text += "\n" + tr(_unavailable_reason(id))
		button.set_pressed_no_signal(command_mode == id)
	_time_label.text = tr("hud.time") % [state.year, C.YEARS, tr("season.rain" if state.is_rain() else "season.dry"), state.turn, C.TURNS_PER_YEAR]
	_resources_label.text = tr("hud.resources") % [state.labor, state.labor_max, state.food, state.wood, state.population, state.capacity()]
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
	var error: String = session.apply(Command.new(id, origin, parameter))
	if not error.is_empty():
		_status_label.text = tr(error)
		return
	wheel_origin = BoardView.NO_COORD
	hovered_coord = coord
	refresh_state()
	board.select(origin)
	if not command_mode.is_empty() and _targets.get(command_mode, []).is_empty():
		_update_command_status()
	else:
		_status_label.text = tr("msg.command_done") % tr("cmd.%s.name" % id)


func undo_command() -> void:
	if not modal_kind.is_empty():
		return
	if session.undo():
		wheel_origin = BoardView.NO_COORD
		refresh_state()


func redo_command() -> void:
	if not modal_kind.is_empty():
		return
	if session.redo():
		wheel_origin = BoardView.NO_COORD
		refresh_state()


func toggle_preview() -> void:
	if not modal_kind.is_empty():
		return
	preview_enabled = not preview_enabled
	_preview_button.set_pressed_no_signal(preview_enabled)
	board.set_preview(prediction, preview_enabled)
	_update_preview_text()
	_update_inspector()


func _update_command_status() -> void:
	if wheel_origin != BoardView.NO_COORD:
		_status_label.text = tr("tile.wheel_direction")
	elif command_mode.is_empty():
		_status_label.text = tr("help.goal")
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
	elif tile.building == C.Building.GATE:
		_tile_note.text = tr("tile.gate_open" if tile.gate_open else "tile.gate_closed")
		if command_mode.is_empty() and state.phase == C.Phase.PLANNING:
			_tile_note.text += "\n" + tr("tile.gate_hint")
	elif tile.building == C.Building.WATERWHEEL:
		var intake: Tile = state.neighbor_in_dir(tile, tile.wheel_dir)
		if intake != null:
			_tile_note.text = tr("tile.wheel_intake") % [intake.q, intake.r]
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
			lines.append(_flood_limit_line(predicted, limits[building]))
	if report.paddies_died.has(tile.coord):
		lines.append(tr("tile.paddy_dies"))
		lines.append(_flood_limit_line(predicted, "paddy_death_level"))
	# Damage is completed even on a losing flood, but production is skipped.
	if report.outcome != C.Outcome.LOSE_HALL:
		if report.paddy_gains.has(tile.coord):
			lines.append(tr("tile.paddy_gain"))
		var fish: int = int(BoardView.preview_fish_food_by_tile(predicted, report).get(tile.coord, 0))
		if fish > 0:
			lines.append(tr("tile.fish_gain") % fish)
	return lines


func _flood_limit_line(predicted: GameState, key: String) -> String:
	var threshold: int = roundi(float(predicted.mods[key]))
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
	return PackedStringArray([
		tr("preview.harvest_title"),
		tr("preview.harvest_paddy") % int(report["paddy_food"]),
		tr("preview.harvest_food") % [int(report["available_food"]), int(report["food_needed"]), int(report["eaten"])],
		tr("preview.harvest_migration") % [int(report["left_hunger"]), int(report["left_housing"])],
		tr("preview.harvest_growth") % [int(report["born"]), int(report["spoiled"])],
		tr("preview.harvest_food_after") % int(report["food_after"]),
		tr("preview.harvest_people") % [int(report["population_after"]), int(report["capacity"])],
	])


func _refresh_save_status() -> void:
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
		_preferences_error = GamePreferences.write({"confirm_unused_labor": false})
	close_modal()
	_finish_turn()


func _finish_turn() -> void:
	if session.advance_turn() == null:
		return
	wheel_origin = BoardView.NO_COORD
	refresh_state()
	if session.state.phase == C.Phase.HARVEST:
		_show_harvest()
	elif session.state.phase == C.Phase.GAME_OVER:
		_show_game_over()


func _open_modal(kind: String, title: String) -> void:
	close_modal()
	modal_kind = kind
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
		board.hover(hovered_coord)


func _add_modal_button(text: String, callback: Callable, node_name: String = "", preferred: bool = false) -> Button:
	var button: Button = _button(text, callback, node_name)
	button.focus_mode = Control.FOCUS_ALL
	_modal_content.add_child(button)
	if preferred:
		button.grab_focus()
	return button


func _show_harvest() -> void:
	_open_modal("harvest", tr("summary.title") % session.state.year)
	for key: String in ["paddy_food", "eaten", "left_hunger", "left_housing", "born", "spoiled", "food_after", "population_after"]:
		_modal_content.add_child(_label(tr("summary." + key) % int(session.state.harvest_report[key])))
	var caption: String = tr("action.finish") if session.state.outcome != C.Outcome.NONE else tr("action.continue")
	_add_modal_button(caption, continue_harvest, "ContinueHarvest", true)
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
	_modal_content.add_child(_label(tr("gameover.seed") % str(state.seed)))
	_add_modal_button(tr("action.restart"), _restart, "Restart")
	_add_modal_button(tr("action.menu"), _return_menu, "GameOverMenu", true)


func _restart() -> void:
	restart_requested.emit({"seed": session.state.seed + 1, "map_type": "plains", "leader": session.state.leader, "difficulty": session.state.difficulty})


func open_pause() -> void:
	if not modal_kind.is_empty() or session.state.phase != C.Phase.PLANNING:
		return
	_open_modal("pause", tr("pause.title"))
	_modal_content.add_child(_label(tr("pause.seed") % str(session.state.seed)))
	_add_modal_button(tr("action.resume"), close_modal, "Resume", true)
	if not session.last_save_error.is_empty():
		_modal_content.add_child(_label(tr(session.last_save_error)))
		_add_modal_button(tr("action.retry_save"), _retry_save, "RetrySave")
	_add_modal_button(tr("action.menu"), _return_menu, "PauseMenu")


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
	var next_coord: Vector2i = BoardView.NO_COORD
	if get_viewport().gui_get_hovered_control() == null:
		var tile: Tile = board.pick(camera_rig.get_camera(), get_viewport().get_mouse_position())
		if tile != null:
			next_coord = tile.coord
	if next_coord != hovered_coord:
		hovered_coord = next_coord
		board.hover(hovered_coord)
		_update_targets()
		_update_inspector()


func _input(event: InputEvent) -> void:
	# Holding the key that opens a summary must not accept its next action.
	if not modal_kind.is_empty() and event is InputEventKey and event.pressed and event.echo and event.is_action("ui_accept"):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if session == null or session.state == null:
		return
	if not modal_kind.is_empty():
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE and modal_kind in ["pause", "confirm_loss", "confirm_labor"]:
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
