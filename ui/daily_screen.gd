class_name DailyScreen
extends Control
## Playable production fixture. Flood dates are authored, not water simulation.

signal menu_requested()

var session: DailySession
var _summary: Label
var _resources: Label
var _objectives: Label
var _preview: Label
var _messages: Label
var _queue: VBoxContainer
var _orders: Dictionary = {}
var _tabs: TabContainer
var _advance_buttons: Array[Button] = []
var _undo_button: Button
var _redo_button: Button
var _restart: ConfirmationDialog
var _log: Array[String] = []
var _last_advance: int = -1000


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.build()
	theme.set_font_size("font_size", "TabBar", 20)
	theme.set_stylebox("tab_selected", "TabBar", ThemeBuilder.box(Color("#284b4d"), 6))
	theme.set_stylebox("tab_unselected", "TabBar", ThemeBuilder.box(Color("#152e31"), 6))
	var background: ColorRect = ColorRect.new()
	background.color = Color(ThemeBuilder.palette()["background"])
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(root)
	var navigation: HBoxContainer = HBoxContainer.new()
	root.add_child(navigation)
	navigation.add_child(_button("menu.back", func(): menu_requested.emit()))
	navigation.add_child(_button("daily.restart", func(): _restart.popup_centered()))
	navigation.add_child(_button("daily.retry_save", _retry_save))
	root.add_child(_label(tr("daily.title"), "Heading"))
	root.add_child(_label(tr("daily.intro"), "Caption"))
	_summary = _label("")
	root.add_child(_summary)
	_resources = _label("")
	root.add_child(_resources)
	_objectives = _label("")
	root.add_child(_objectives)
	var time: HBoxContainer = HBoxContainer.new()
	root.add_child(time)
	for days: int in [1, 7, 365]:
		var key: String = "daily.next_event" if days == 365 else ("daily.day" if days == 1 else "daily.week")
		var button: Button = _button(key, _advance.bind(days))
		time.add_child(button)
		_advance_buttons.append(button)
	_undo_button = _button("daily.undo", _undo)
	time.add_child(_undo_button)
	_redo_button = _button("daily.redo", _redo)
	time.add_child(_redo_button)
	_preview = _label("", "Caption")
	root.add_child(_preview)
	_messages = _label("", "Caption")
	root.add_child(_messages)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	var production: VBoxContainer = VBoxContainer.new()
	production.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(production)
	production.add_child(_label(tr("daily.production"), "Heading"))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	production.add_child(_tabs)
	var groups: Array[VBoxContainer] = []
	var scrolls: Array[ScrollContainer] = []
	for group: String in ["gather", "build", "craft"]:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.name = group
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tabs.add_child(scroll)
		_tabs.set_tab_title(_tabs.get_tab_count() - 1, tr("daily.tab." + group))
		var list: VBoxContainer = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		groups.append(list)
		scrolls.append(scroll)
	for id: String in DailyProduction.config()["jobs"]:
		var group: int = 0 if id.begins_with("gather_") else (1 if id.begins_with("build_") else 2)
		var panel: PanelContainer = PanelContainer.new()
		groups[group].add_child(panel)
		var content: VBoxContainer = VBoxContainer.new()
		panel.add_child(content)
		content.add_child(_label(tr("daily.job." + id)))
		content.add_child(_label(_description(id), "Caption"))
		var row: HBoxContainer = HBoxContainer.new()
		content.add_child(row)
		var amount: SpinBox = SpinBox.new()
		amount.min_value = 1
		amount.max_value = 1 if DailyProduction.config()["jobs"][id].has("builds") else 20
		amount.value = 1
		amount.custom_minimum_size.x = 110
		row.add_child(amount)
		var order: Button = _button("daily.order", _order.bind(id, amount))
		order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(order)
		var reason: Label = _label("", "Caption")
		content.add_child(reason)
		_orders[id] = {"amount": amount, "button": order, "reason": reason, "tab": group, "scroll": scrolls[group]}
		amount.value_changed.connect(func(_value: float): _refresh_orders())
	_tabs.current_tab = 1
	var queue_panel: VBoxContainer = VBoxContainer.new()
	queue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_panel.custom_minimum_size.x = 380
	columns.add_child(queue_panel)
	queue_panel.add_child(_label(tr("daily.queue"), "Heading"))
	queue_panel.add_child(_label(tr("daily.queue_help"), "Caption"))
	var queue_scroll: ScrollContainer = ScrollContainer.new()
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_panel.add_child(queue_scroll)
	_queue = VBoxContainer.new()
	_queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.add_child(_queue)
	_restart = ConfirmationDialog.new()
	_restart.title = tr("daily.restart")
	_restart.dialog_text = tr("daily.restart_confirm")
	_restart.confirmed.connect(_restart_run)
	add_child(_restart)
	if session == null:
		session = DailySession.new()
	if session.daily.is_empty():
		var error: String = session.load_prototype()
		if error == "msg.no_save":
			error = session.start_prototype()
		if not error.is_empty():
			_log.append(tr(error))
	_refresh()


func _label(value: String, style: String = "") -> Label:
	var label: Label = Label.new()
	label.text = value
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


func _materials(values: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for resource: String in DailyProduction.RESOURCES:
		if values.has(resource):
			parts.append("%s %d" % [tr("daily.resource." + resource), int(values[resource])])
	return " · ".join(parts) if not parts.is_empty() else tr("daily.none")


func _description(id: String) -> String:
	var definition: Dictionary = DailyProduction.config()["jobs"][id]
	var text: String = tr("daily.recipe") % [int(definition["workers"]), int(definition["days"]), _materials(definition["inputs"]), _materials(definition["outputs"])]
	if definition.has("knowledge"):
		text += "\n" + tr("daily.knowledge_cost") % int(definition["knowledge"])
	return text


func _refresh_orders() -> void:
	for id: String in _orders:
		var entry: Dictionary = _orders[id]
		var error: String = "daily.error.order" if session == null or session.daily.is_empty() else DailyProduction.check_order(session.daily, id, int(entry["amount"].value))
		entry["button"].disabled = not error.is_empty()
		entry["reason"].text = "" if error.is_empty() else tr(error)


func _refresh() -> void:
	var s: Dictionary = session.daily
	_refresh_orders()
	for button: Button in _advance_buttons:
		button.disabled = s.is_empty() or s["outcome"] != "running"
	_undo_button.disabled = session._undo_daily.is_empty()
	_redo_button.disabled = session._redo_daily.is_empty()
	_messages.text = "\n".join(_log)
	if not session.last_save_error.is_empty():
		_messages.text += "\n" + tr(session.last_save_error)
	if s.is_empty():
		return
	_summary.text = tr("daily.status") % [int(s["day"]), int(DailyProduction.config()["duration"]), DailyProduction.workers_used(s), int(DailyProduction.config()["population"]), int(s["knowledge"]), tr("daily.outcome." + String(s["outcome"]))]
	_resources.text = _materials(s["resources"])
	_objectives.text = tr("daily.objectives") % [mini(2, int(s["planks_produced"])), tr("daily.done" if s["buildings"]["foundation"] else "daily.pending"), tr("daily.done" if s["buildings"]["barrier"] else "daily.pending")]
	var next: Dictionary = DailyProduction.preview(s)
	_preview.text = tr("daily.preview") % [int(next["state"]["resources"]["food"]), _event_text(next["report"]["events"])]
	for child: Node in _queue.get_children():
		_queue.remove_child(child)
		child.queue_free()
	if s["jobs"].is_empty():
		_queue.add_child(_label(tr("daily.empty_queue"), "Caption"))
	for job: Dictionary in s["jobs"]:
		var card: PanelContainer = PanelContainer.new()
		_queue.add_child(card)
		var content: VBoxContainer = VBoxContainer.new()
		card.add_child(content)
		content.add_child(_label(tr("daily.job." + String(job["id"]))))
		content.add_child(_label(tr("daily.job_progress") % [int(job["remaining"]), int(job["progress"]), int(DailyProduction.config()["jobs"][job["id"]]["days"]), tr("daily.paused" if job["paused"] else "daily.working")], "Caption"))
		var row: HBoxContainer = HBoxContainer.new()
		content.add_child(row)
		var pause: Button = _button("daily.resume" if job["paused"] else "daily.pause", _edit.bind("pause", String(job["id"]), 1))
		pause.disabled = s["outcome"] != "running"
		row.add_child(pause)
		var cancel: Button = _button("daily.cancel", _edit.bind("cancel", String(job["id"]), 1))
		cancel.disabled = s["outcome"] != "running"
		row.add_child(cancel)


func _event_text(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for event: String in events:
		parts.append(tr(event))
	return " · ".join(parts) if not parts.is_empty() else tr("daily.no_event")


func _order(id: String, amount: SpinBox) -> void:
	_edit("order", id, int(amount.value))


func _edit(action: String, id: String, batches: int) -> void:
	var error: String = session.edit(action, id, batches)
	if not error.is_empty():
		_log = [tr(error)]
	_refresh()


func _advance(days: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_advance < 400:
		return
	_last_advance = now
	get_viewport().set_input_as_handled()
	var report: Dictionary = session.advance_days(days)
	_log = [tr("daily.advanced") % int(report["days"]), _event_text(report["events"])]
	_refresh()


func _undo() -> void:
	session.undo_daily()
	_refresh()


func _redo() -> void:
	session.redo_daily()
	_refresh()


func _retry_save() -> void:
	session.checkpoint_daily()
	_refresh()


func _restart_run() -> void:
	session.start_prototype()
	_log.clear()
	_refresh()
