class_name YearScreen
extends Control

signal menu_requested()
var session: YearSession
var initial_seed: int = 42
var initial_goal: String = "none"
var board: YearBoard
var selected: int = -1
var _status: Label
var _resources: Label
var _forecast: Label
var _inspection: Label
var _recipe: Label
var _reason: Label
var _messages: Label
var _summary: Label
var _notice: Label
var _latest_notice: String = ""
var _tabs: TabContainer
var _group: OptionButton
var _action: OptionButton
var _batches: SpinBox
var _repeat: CheckBox
var _direction: OptionButton
var _order_button: Button
var _gate_button: Button
var _queue: VBoxContainer
var _research: Dictionary = {}
var _challenges: Label
var _preview: CheckBox
var _time_buttons: Array[Button] = []
var _undo: Button
var _redo: Button
var _restart: ConfirmationDialog
var _new_button: Button
var _seed: LineEdit
var _goal: OptionButton
var _last_advance: int = -1000
var _log: Array[String] = []
var _predicted: Dictionary = {}

const GROUPS: Array[String] = ["food", "materials", "build", "land"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.build()
	var background: ColorRect = ColorRect.new()
	background.color = Color("#0b2128")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	margin.add_child(root)
	var nav: HBoxContainer = HBoxContainer.new()
	root.add_child(nav)
	nav.add_child(_button("menu.back", func(): menu_requested.emit()))
	_new_button = _button("year.new", func(): _restart.popup_centered(Vector2i(650, 320)))
	nav.add_child(_new_button)
	nav.add_child(_button("daily.retry_save", func(): session.checkpoint_year(); _refresh()))
	var title: Label = _label(tr("year.title"), "Heading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(title)
	_status = _label("")
	root.add_child(_status)
	_resources = _label("")
	root.add_child(_resources)
	var time: HBoxContainer = HBoxContainer.new()
	root.add_child(time)
	for days: int in [1, 7, 365]:
		var button: Button = _button("daily.next_event" if days == 365 else ("daily.day" if days == 1 else "daily.week"), _advance.bind(days))
		time.add_child(button)
		_time_buttons.append(button)
	_undo = _button("daily.undo", func(): session.undo_year(); _refresh())
	time.add_child(_undo)
	_redo = _button("daily.redo", func(): session.redo_year(); _refresh())
	time.add_child(_redo)
	_preview = CheckBox.new()
	_preview.text = tr("year.preview")
	_preview.toggled.connect(func(_enabled: bool): _refresh_selection())
	time.add_child(_preview)
	_forecast = _label("", "Caption")
	root.add_child(_forecast)
	_notice = _label("", "Caption")
	_notice.max_lines_visible = 2
	root.add_child(_notice)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	var map_column: VBoxContainer = VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.size_flags_stretch_ratio = 1.3
	columns.add_child(map_column)
	board = YearBoard.new()
	board.custom_minimum_size = Vector2(600, 400)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.tile_selected.connect(select_tile)
	map_column.add_child(board)
	map_column.add_child(_label(tr("year.map_help"), "Caption"))
	_summary = _label("", "Caption")
	map_column.add_child(_summary)
	var tabs: TabContainer = TabContainer.new()
	_tabs = tabs
	tabs.custom_minimum_size.x = 650
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(tabs)
	var actions: VBoxContainer = _tab(tabs, "year.actions")
	_inspection = _label("")
	actions.add_child(_inspection)
	_group = OptionButton.new()
	for group: String in GROUPS:
		_group.add_item(tr("year.group." + group))
	actions.add_child(_group)
	_group.item_selected.connect(func(_index: int): _populate_actions())
	_action = OptionButton.new()
	actions.add_child(_action)
	_action.item_selected.connect(func(_index: int): _refresh_selection())
	_recipe = _label("", "Caption")
	actions.add_child(_recipe)
	var quantity: HBoxContainer = HBoxContainer.new()
	actions.add_child(quantity)
	_batches = SpinBox.new()
	_batches.min_value = 1
	_batches.max_value = 100
	_batches.value = 1
	_batches.custom_minimum_size.x = 130
	quantity.add_child(_batches)
	_repeat = CheckBox.new()
	_repeat.text = tr("year.repeat")
	quantity.add_child(_repeat)
	_repeat.toggled.connect(func(enabled: bool):
		if enabled:
			_batches.value = 1
		_batches.editable = not enabled
		_refresh_selection()
	)
	_batches.value_changed.connect(func(_value: float): _refresh_selection())
	_direction = OptionButton.new()
	for direction: String in ["e", "ne", "nw", "w", "sw", "se"]:
		_direction.add_item(tr("year.direction." + direction))
	actions.add_child(_direction)
	_direction.item_selected.connect(func(_index: int): _refresh_selection())
	_order_button = _button("year.order", _order)
	actions.add_child(_order_button)
	_gate_button = _button("year.gate", func(): _edit("gate"))
	actions.add_child(_gate_button)
	_reason = _label("", "Caption")
	actions.add_child(_reason)
	actions.add_child(_label(tr("year.order_help"), "Caption"))
	_queue = _tab(tabs, "year.work")
	var learning: VBoxContainer = _tab(tabs, "year.research")
	learning.add_child(_label(tr("year.research_help"), "Caption"))
	for id: String in YearGame.config()["research"]:
		var button: Button = _button("year.research." + id, _learn.bind(id))
		button.tooltip_text = tr("year.research." + id + "_desc")
		learning.add_child(button)
		learning.add_child(_label(tr("year.research." + id + "_desc"), "Caption"))
		_research[id] = button
	var challenges: VBoxContainer = _tab(tabs, "year.challenges")
	_challenges = _label("")
	challenges.add_child(_challenges)
	var reports: VBoxContainer = _tab(tabs, "year.report")
	_messages = _label("")
	reports.add_child(_messages)
	_restart = ConfirmationDialog.new()
	_restart.title = tr("year.new")
	_restart.ok_button_text = tr("menu.overwrite_confirm")
	_restart.cancel_button_text = tr("action.cancel")
	_restart.dialog_text = ""
	var setup: VBoxContainer = VBoxContainer.new()
	setup.custom_minimum_size.x = 600
	_restart.add_child(setup)
	var confirmation: Label = _label(tr("year.restart_confirm"), "Caption")
	confirmation.autowrap_mode = TextServer.AUTOWRAP_OFF
	setup.add_child(confirmation)
	var seed_label: Label = _label(tr("setup.seed"))
	seed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	setup.add_child(seed_label)
	_seed = LineEdit.new()
	_seed.text = str(initial_seed)
	setup.add_child(_seed)
	_goal = OptionButton.new()
	for goal: String in ["none", "growth", "forest", "rice"]:
		_goal.add_item(tr("goal." + goal + ".name"))
	setup.add_child(_goal)
	_restart.confirmed.connect(_new_year)
	add_child(_restart)
	if session == null:
		session = YearSession.new()
	if session.year.is_empty():
		var error: String = session.load_year()
		if error == "msg.no_save":
			error = session.start_year(initial_seed, initial_goal)
		if not error.is_empty():
			_log.append(tr(error))
	_populate_actions()
	if not session.year.is_empty():
		selected = session.year["structures"].find("hall")
	_refresh()


func _label(text: String, style: String = "") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not style.is_empty():
		label.theme_type_variation = style
	return label


func _button(key: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = tr(key)
	button.pressed.connect(callback)
	return button


func _tab(tabs: TabContainer, key: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tr(key))
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _populate_actions() -> void:
	_action.clear()
	for id: String in YearGame.config()["jobs"]:
		var group: String = "build" if id.begins_with("build_") or id == "upgrade_house" else ("food" if id in ["forage", "fish", "plant_paddy", "harvest"] else ("materials" if id.begins_with("gather_") or id in ["saw_planks", "fire_bricks"] else "land"))
		if group == GROUPS[_group.selected]:
			_action.add_item(tr("year.action." + id))
			_action.set_item_metadata(_action.item_count - 1, id)
	_refresh_selection()


func action_id() -> String:
	return "" if _action.selected < 0 else String(_action.get_item_metadata(_action.selected))


func select_tile(index: int) -> void:
	selected = index
	_refresh_selection()


func _materials(values: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for resource: String in YearGame.RESOURCES:
		if values.has(resource):
			parts.append("%s %d" % [tr("daily.resource." + resource), int(values[resource])])
	return " · ".join(parts) if not parts.is_empty() else tr("daily.none")


func _refresh_selection() -> void:
	if _order_button == null or session == null or session.year.is_empty() or selected < 0:
		return
	var s: Dictionary = session.year
	var tile: Dictionary = s["board"]["tiles"][selected]
	var structure: String = s["structures"][selected]
	var site: String = String(tile["feature"]) if structure.is_empty() else structure
	_inspection.text = tr("year.tile") % [int(tile["q"]), int(tile["r"]), tr("year.site." + site), int(tile["elevation"]), float(tile["water"]), int(s["health"][selected]), int(s["crop_growth"][selected]), int(s["stock"][selected])]
	if _preview.button_pressed and not _predicted.is_empty():
		_inspection.text += "\n" + tr("year.preview_tile") % [float(_predicted["board"]["tiles"][selected]["water"]), int(_predicted["health"][selected])]
	var id: String = action_id()
	if id.is_empty():
		return
	var definition: Dictionary = YearGame.config()["jobs"][id]
	var reusable: bool = id in YearGame.REPEATABLE
	_repeat.disabled = not reusable
	if not reusable:
		_repeat.set_pressed_no_signal(false)
		_batches.value = 1
	_batches.max_value = 100 if reusable else 1
	_batches.editable = reusable and not _repeat.button_pressed
	_direction.visible = id == "build_wheel"
	_recipe.text = tr("year.recipe") % [int(definition["workers"]), YearGame._job_days(s, id), _materials(definition["inputs"]), _materials(definition["outputs"])]
	_recipe.text += "\n" + tr("year.action." + id + "_desc")
	var error: String = YearGame.check_order(s, id, selected, int(_batches.value), _repeat.button_pressed, _direction.selected)
	_reason.text = "" if error.is_empty() else tr(error)
	_order_button.disabled = not error.is_empty()
	_gate_button.disabled = structure != "gate" or int(s["health"][selected]) <= 0 or s["outcome"] != "running"
	board.model = s
	board.selected = selected
	board.targets.clear()
	for index: int in range(61):
		if YearGame.check_order(s, id, index, int(_batches.value), _repeat.button_pressed, _direction.selected).is_empty():
			board.targets.append(index)
	board.predicted = _predicted if _preview.button_pressed else {}
	board.queue_redraw()


func _refresh() -> void:
	if session.year.is_empty():
		for button: Button in _time_buttons:
			button.disabled = true
		_order_button.disabled = true
		_messages.text = tr(session.last_save_error)
		return
	var s: Dictionary = session.year
	var need: int = YearGame.food_need(s)
	_status.text = tr("year.status") % [int(s["day"]), tr("year.season." + DailyProduction.season(maxi(1, int(s["day"])))), int(s["population"]), YearGame.housing(s), YearGame.workers(s), int(s["population"]), int(s["resources"]["food"]) / maxi(1, need), int(s["knowledge"])]
	_resources.text = _materials(s["resources"])
	var forecast: PackedStringArray = PackedStringArray()
	for entry: Dictionary in YearWeather.forecast(s):
		forecast.append("%d: %.2f" % [int(entry["day"]), float(entry["inflow"])])
	_forecast.text = tr("year.forecast") + " · ".join(forecast)
	_predicted = YearGame.preview(s)["state"]
	_refresh_selection()
	_undo.disabled = session.undo_plans.is_empty()
	_redo.disabled = session.redo_plans.is_empty()
	for button: Button in _time_buttons:
		button.disabled = s["outcome"] != "running"
	_summary.text = tr("year.summary") % [tr("year.outcome." + String(s["outcome"])), int(s["score"]), int(s["stats"]["harvest"]), int(s["stats"]["born"]), int(s["stats"]["departed"])]
	_summary.text += "\n" + tr("year.goal." + String(s["goal"]))
	if not session.last_save_error.is_empty():
		_summary.text += "\n" + tr(session.last_save_error)
	_messages.text = "\n".join(_log)
	_notice.text = _latest_notice
	_notice.visible = not _latest_notice.is_empty()
	var challenges: PackedStringArray = PackedStringArray()
	for id: String in YearGame.config()["challenges"]:
		challenges.append("%s · %s · +%d\n%s" % [tr("year.challenge." + id), tr("daily.done" if id in s["claimed"] else "daily.pending"), int(YearGame.config()["challenges"][id]), tr("year.challenge." + id + "_desc")])
	_challenges.text = "\n\n".join(challenges)
	for id: String in _research:
		var definition: Dictionary = YearGame.config()["research"][id]
		var learned: bool = id in s["research"]
		_research[id].text = tr("year.research." + id) + (" · " + tr("daily.done") if learned else " · %d" % int(definition["cost"]))
		_research[id].disabled = learned or s["outcome"] != "running" or int(s["knowledge"]) < int(definition["cost"]) or (not String(definition["requires"]).is_empty() and definition["requires"] not in s["research"])
	for child: Node in _queue.get_children():
		_queue.remove_child(child)
		child.queue_free()
	if s["jobs"].is_empty():
		_queue.add_child(_label(tr("daily.empty_queue")))
	for job: Dictionary in s["jobs"]:
		var index: int = int(job["tile"])
		var container: VBoxContainer = VBoxContainer.new()
		_queue.add_child(container)
		container.add_child(_label(tr("year.action." + String(job["id"])) + " · " + tr(YearGame.job_status(s, job))))
		container.add_child(_label(tr("daily.job_progress") % [int(job["remaining"]), int(job["progress"]), YearGame._job_days(s, job["id"]), tr("year.repeat") if job["repeat"] else tr("daily.working")], "Caption"))
		var row: HBoxContainer = HBoxContainer.new()
		container.add_child(row)
		row.add_child(_button("year.locate", select_tile.bind(index)))
		var pause: Button = _button("daily.resume" if job["paused"] else "daily.pause", _edit_job.bind(index, false))
		pause.name = "PauseTile_" + str(index)
		row.add_child(pause)
		var cancel: Button = _button("daily.cancel", _edit_job.bind(index, true))
		cancel.name = "CancelTile_" + str(index)
		row.add_child(cancel)


func _edit(action: String, id: String = "") -> void:
	var error: String = session.edit_year(action, id, selected, int(_batches.value), _repeat.button_pressed, _direction.selected)
	if not error.is_empty():
		_log.append(tr(error))
		_latest_notice = tr(error)
	_refresh()


func _order() -> void:
	_edit("order", action_id())


func _learn(id: String) -> void:
	_edit("learn", id)


func _edit_job(index: int, cancel: bool) -> void:
	selected = index
	_edit("cancel" if cancel else "pause")


func _advance(days: int) -> void:
	if session == null or session.year.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_advance < 400:
		return
	_last_advance = now
	get_viewport().set_input_as_handled()
	var before: Dictionary = session.year["resources"].duplicate(true)
	var report: Dictionary = session.advance_year(days)
	var events: PackedStringArray = PackedStringArray()
	for event: String in report["events"]:
		if tr(event) not in events:
			events.append(tr(event))
	_latest_notice = " · ".join(events)
	_log.append(tr("year.report_day") % [int(session.year["day"]), int(report["days"])] + "\n" + " · ".join(events) + "\n" + _materials(before) + " → " + _materials(session.year["resources"]))
	while _log.size() > 30:
		_log.pop_front()
	_refresh()


func _new_year() -> void:
	initial_seed = SeedUtil.parse_seed_text(_seed.text)
	initial_goal = ["none", "growth", "forest", "rice"][_goal.selected]
	session.start_year(initial_seed, initial_goal)
	_log.clear()
	_latest_notice = ""
	if not session.year.is_empty():
		selected = session.year["structures"].find("hall")
	_refresh()
