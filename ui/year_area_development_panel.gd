class_name YearAreaDevelopmentPanel
extends VBoxContainer
## Contextual form. Previewing never writes; the owner validates the snapshot.
signal command_requested(order: Dictionary, snapshot: Dictionary)

var source_snapshot: Dictionary = {}
var tile_index: int = -1
var _options: Array[Dictionary] = []
var _choice: OptionButton
var _horizon: OptionButton
var _batches: SpinBox
var _repeat: CheckBox
var _direction: OptionButton
var _details: Label
var _identity: Label
var _recipe: Label
var _apply: Button
var _trial: Button
var _pending: Dictionary = {}
var _result: Dictionary = {}
var _quantity: HBoxContainer


func _ready() -> void:
	_identity = _label("")
	add_child(_identity)
	_choice = OptionButton.new()
	_choice.fit_to_longest_item = false
	_choice.clip_text = true
	_choice.item_selected.connect(func(_index: int): _selection_changed())
	add_child(_choice)
	_recipe = _label("")
	add_child(_recipe)
	var row: HBoxContainer = HBoxContainer.new()
	_quantity = row
	add_child(row)
	row.add_child(_label(tr("yeararea.batches")))
	_batches = SpinBox.new()
	_batches.min_value = 1
	_batches.max_value = 100
	_batches.value = 1
	_batches.value_changed.connect(func(_value: float): _invalidate())
	row.add_child(_batches)
	_repeat = CheckBox.new()
	_repeat.text = tr("year.repeat")
	_repeat.toggled.connect(func(enabled: bool):
		if enabled:
			_batches.value = 1
		_batches.editable = not enabled
		_invalidate()
	)
	row.add_child(_repeat)
	_direction = OptionButton.new()
	for direction: String in ["e", "ne", "nw", "w", "sw", "se"]:
		_direction.add_item(tr("year.direction." + direction))
	_direction.item_selected.connect(func(_index: int): _invalidate())
	add_child(_direction)
	_horizon = OptionButton.new()
	_horizon.add_item(tr("yearreview.seven"))
	_horizon.add_item(tr("yearreview.until_complete"))
	_horizon.item_selected.connect(func(_index: int): _invalidate())
	add_child(_horizon)
	_trial = Button.new()
	_trial.text = tr("yeararea.preview")
	_trial.pressed.connect(_preview)
	add_child(_trial)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_details = _label("")
	_details.focus_mode = Control.FOCUS_ALL
	scroll.add_child(_details)
	_apply = Button.new()
	_apply.text = tr("yeararea.apply")
	_apply.pressed.connect(_request_command)
	add_child(_apply)


func _label(value: String) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func configure(s: Dictionary, index: int, notice: String = "") -> void:
	source_snapshot = s.duplicate(true)
	tile_index = index
	var tile: Dictionary = s["board"]["tiles"][index]
	var site: String = s["structures"][index]
	if site.is_empty():
		site = s["deposits"][index] if not String(s["deposits"][index]).is_empty() else tile["feature"]
	_identity.text = tr("year.tile") % [int(tile["q"]), int(tile["r"]), tr("year.site." + site), int(tile["elevation"]), float(tile["water"]), int(s["health"][index]), int(s["crop_growth"][index]), int(s["stock"][index])]
	_identity.text += "\n" + tr("yeararea.role." + YearAreaDevelopment.role(s, index))
	_options = YearAreaDevelopment.options(s, index)
	_choice.clear()
	for option: Dictionary in _options:
		var key: String = "year.action." + String(option["id"]) if option["action"] == "order" else ("year.gate" if option["action"] == "gate" else "yearplus.policy." + String(option["id"]))
		_choice.add_item(tr(key))
	_selection_changed()
	if not notice.is_empty():
		_details.text = notice


func _selection_changed() -> void:
	_invalidate()
	_trial.disabled = _options.is_empty()
	_direction.hide()
	_repeat.hide()
	_batches.hide()
	_quantity.hide()
	if _options.is_empty():
		_recipe.text = tr("yeararea.no_actions")
		return
	var option: Dictionary = _options[_choice.selected]
	if option["action"] != "order":
		_recipe.text = tr("yeararea.instant")
		return
	var id: String = option["id"]
	var definition: Dictionary = YearGame.config(source_snapshot)["jobs"][id]
	var reusable: bool = id in YearGame.repeatable(source_snapshot)
	_quantity.visible = reusable
	_repeat.visible = reusable
	_batches.visible = reusable
	if not reusable:
		_repeat.set_pressed_no_signal(false)
		_batches.value = 1
	_batches.editable = not _repeat.button_pressed
	_direction.visible = id == "build_wheel"
	_recipe.text = tr("year.recipe") % [int(definition["workers"]), YearGame._job_days(source_snapshot, id, tile_index), YearPlanText.materials(source_snapshot, YearExpansion.inputs(source_snapshot, id, tile_index)), YearPlanText.materials(source_snapshot, YearAreaDevelopment.expected_output(source_snapshot, id, tile_index))]
	_recipe.text += "\n" + tr("year.action." + id + "_desc") + "\n" + tr("yeararea.output_hint")


func _invalidate() -> void:
	_result.clear()
	_pending.clear()
	if _apply != null:
		_apply.disabled = true
	if _details != null:
		_details.text = tr("yeararea.not_committed")


func _preview() -> void:
	get_viewport().set_input_as_handled()
	if _options.is_empty():
		return
	var option: Dictionary = _options[_choice.selected]
	_pending = {"action": option["action"], "id": option["id"], "tile": tile_index, "batches": int(_batches.value), "repeat": _repeat.button_pressed, "direction": _direction.selected, "stop_at": 0, "reserve": 0}
	var o: Dictionary = _pending
	_result = YearOrderPreview.describe(source_snapshot, o["id"], tile_index, o["batches"], o["repeat"], o["direction"], 0, 0, _horizon.selected == 1, o["action"])
	if not String(_result["error"]).is_empty():
		_details.text = tr(_result["error"])
		_apply.disabled = true
		return
	_details.text = YearPlanText.describe(source_snapshot, _result, tile_index)
	if o["repeat"] and _horizon.selected == 1:
		_details.text = tr("yearreview.first_batch") + "\n\n" + _details.text
	_apply.disabled = false
	_details.call_deferred("grab_focus")


func _request_command() -> void:
	get_viewport().set_input_as_handled()
	if _apply.disabled or _pending.is_empty():
		return
	_apply.disabled = true
	command_requested.emit(_pending.duplicate(true), source_snapshot.duplicate(true))
