class_name AreaDevelopmentPanel
extends VBoxContainer
## A local plan is read-only until the player explicitly applies it.
signal command_requested(command: Command)
signal close_requested

var _state: GameState
var _coord: Vector2i
var _baseline: Dictionary
var _options: Array[String] = []
var _consumed: bool = false
var _plan: Dictionary = {}
var _command: Command
var _identity: Label
var _role: Label
var _choice: OptionButton
var _parameter: OptionButton
var _details: VBoxContainer
var _receipt: Label
var _apply: Button
var _back: Button
var source_snapshot: Dictionary = {}


func _ready() -> void:
	_identity = _label("", 22)
	add_child(_identity)
	_role = _label("", 18)
	add_child(_role)
	_choice = OptionButton.new()
	_choice.name = "AreaAction"
	_choice.fit_to_longest_item = false
	_choice.clip_text = true
	_choice.custom_minimum_size.y = 42
	_choice.item_selected.connect(_select_action)
	add_child(_choice)
	_parameter = OptionButton.new()
	_parameter.name = "AreaParameter"
	_parameter.fit_to_longest_item = false
	_parameter.clip_text = true
	_parameter.custom_minimum_size.y = 42
	_parameter.item_selected.connect(_select_parameter)
	add_child(_parameter)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "AreaPlanDetails"
	scroll.custom_minimum_size = Vector2(704, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_details)
	_receipt = _label("", 18)
	_receipt.name = "AreaCommandReceipt"
	_receipt.focus_mode = Control.FOCUS_ALL
	add_child(_receipt)
	_apply = _button(tr("area.apply"), "ApplyAreaCommand")
	_apply.theme_type_variation = "PrimaryButton"
	_apply.pressed.connect(_request_command)
	add_child(_apply)
	_back = _button(tr("area.back"), "CloseAreaDevelopment")
	_back.pressed.connect(func(): get_viewport().set_input_as_handled(); close_requested.emit())
	add_child(_back)


func configure(state: GameState, coord: Vector2i, baseline: Dictionary, applied: bool = false, notice: String = "") -> void:
	var previous: String = _options[_choice.selected] if _choice.selected >= 0 and _choice.selected < _options.size() else ""
	_state = state
	source_snapshot = state.to_dict()
	_coord = coord
	_baseline = baseline
	_consumed = applied
	var tile: Tile = state.get_tile(coord)
	var category: String = AreaDevelopment.category(tile)
	_identity.text = tr("area.identity") % [coord.x, coord.y, tr("area.type." + category)]
	_role.text = tr("area.role." + category)
	_options = AreaDevelopment.options(state, coord)
	_choice.clear()
	for id: String in _options:
		_choice.add_item(_command_name(id))
	_choice.visible = not _options.is_empty()
	_receipt.text = notice
	_receipt.visible = not notice.is_empty()
	if _options.is_empty():
		_parameter.hide()
		_command = null
		_render_plan()
	else:
		_choice.select(maxi(0, _options.find(previous)))
		_fill_parameters()
		_render_plan()
	if applied:
		# A receipt accepts focus without accepting another command. Queued
		# Enter/Space events cannot apply again or close into the board.
		_receipt.grab_focus()
	else:
		_back.grab_focus()


func _select_action(_index: int) -> void:
	get_viewport().set_input_as_handled()
	_consumed = false
	_fill_parameters()
	_render_plan()


func _fill_parameters() -> void:
	var id: String = _options[_choice.selected]
	_parameter.clear()
	_parameter.visible = id in ["waterwheel", "irrigation_policy"]
	var selected: int = 0
	var found: bool = false
	if id == "waterwheel":
		for direction: int in range(6):
			var neighbor: Tile = _state.neighbor_in_dir(_state.get_tile(_coord), direction)
			_parameter.add_item(tr("tile.wheel_intake") % [neighbor.q, neighbor.r] if neighbor != null else tr("area.outside"), direction)
			_parameter.set_item_disabled(direction, neighbor == null or neighbor.is_sea)
			if not found and neighbor != null and not neighbor.is_sea:
				selected = direction
				found = true
	elif id == "irrigation_policy":
		for index: int in range(Irrigation.POLICIES.size()):
			_parameter.add_item(tr("irrigation." + Irrigation.POLICIES[index]), index)
			if not found and Irrigation.POLICIES[index] != _state.get_tile(_coord).irrigation_policy:
				selected = index
				found = true
	if _parameter.item_count > 0:
		_parameter.select(selected)
	_command = Command.new(id, _coord, selected if _parameter.visible else -1)


func _select_parameter(index: int) -> void:
	get_viewport().set_input_as_handled()
	_consumed = false
	_command.param = _parameter.get_item_id(index)
	_render_plan()


func _render_plan() -> void:
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var tile: Tile = _state.get_tile(_coord)
	_line(tr("area.current"), true)
	_line(tr("tile.details") % [tile.elevation, tile.water, tr("level.%d" % _state.level_of(tile))])
	_line(tr("area.not_committed"))
	_apply.text = tr("area.applied" if _consumed else "area.apply")
	_apply.disabled = true
	_plan = {}
	if _command == null:
		_line(tr("area.no_actions"))
		return
	_line(tr("irrigation.select_hint") if _command.id == "irrigation_policy" else tr("cmd." + _command.id + ".desc"))
	var cost: Vector2i = CommandRules.cost(_state, _command)
	_line(tr("hud.command_cost") % [cost.x, cost.y], true)
	_plan = AreaDevelopment.preview(_state, _command)
	if not String(_plan["error"]).is_empty():
		_line(tr(String(_plan["error"])))
		return
	var after: GameState = _plan["state"]
	var planned_tile: Tile = after.get_tile(_coord)
	_line(tr("area.after_command"), true)
	_line(tr("area.resources") % [_state.labor, after.labor, _state.wood, after.wood, _state.capacity(), after.capacity()])
	_line(tr("area.land_change") % [tile.elevation, planned_tile.elevation, tr("area.type." + AreaDevelopment.category(tile)), tr("area.type." + AreaDevelopment.category(planned_tile))])
	var predicted: GameState = _plan["prediction"]["state"]
	var next_tile: Tile = predicted.get_tile(_coord)
	_line(tr("area.after_turn"), true)
	_line(tr("tile.predicted") % [next_tile.water, tr("level.%d" % predicted.level_of(next_tile))])
	if not _baseline.is_empty():
		var before_report: TurnReport = _baseline["report"]
		var report: TurnReport = _plan["prediction"]["report"]
		_line(tr("area.compare_damage") % [before_report.destroyed.size(), report.destroyed.size(), before_report.paddies_died.size(), report.paddies_died.size()])
		_line(tr("area.compare_food") % [before_report.paddy_gains.size(), report.paddy_gains.size(), before_report.fish_food, report.fish_food])
	if not _plan["harvest"].is_empty():
		_line(tr("area.harvest") % [int(_plan["harvest"]["food_after"]), int(_plan["harvest"]["population_after"])])
	if int(_plan["outcome"]) != C.Outcome.NONE:
		_line(tr("gameover." + C.enum_name(C.Outcome, int(_plan["outcome"]))), true)
	_line(tr("history.yield_note"))
	_apply.disabled = _consumed


func _request_command() -> void:
	get_viewport().set_input_as_handled()
	if _consumed or _command == null or _plan.is_empty() or not String(_plan["error"]).is_empty():
		return
	_consumed = true
	_apply.disabled = true
	command_requested.emit(Command.new(_command.id, _command.coord, _command.param))


func _command_name(id: String) -> String:
	return tr("area.irrigation") if id == "irrigation_policy" else tr("cmd." + id + ".name")


func _line(text: String, heading: bool = false) -> void:
	_details.add_child(_label(text, 20 if heading else 18))


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, node_name: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 42
	button.theme_type_variation = "QuietButton"
	return button
