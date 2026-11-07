class_name TransportPanel
extends VBoxContainer

signal changed()
signal route_changed()
signal site_requested(index: int)
var session: TransportSession
var prediction: Dictionary = {}
var _stock: Label
var _forecast: Label
var _route: Label
var _error: Label
var _queue: VBoxContainer
var _batches: SpinBox
var _amount: SpinBox
var _mode: OptionButton
var _leg: OptionButton
var _buttons: Dictionary = {}
var _ports: Dictionary = {}
var _last_error: String = ""


func _ready() -> void:
	add_child(_label(tr("transport.intro"), "Caption"))
	_stock = _label("")
	add_child(_stock)
	var sites: HBoxContainer = HBoxContainer.new()
	add_child(sites)
	for role: String in TransportGame.ROLES:
		var button: Button = _button("transport.site." + role, func():
			if not session.year.is_empty():
				site_requested.emit(int(session.transport["sites"][role]))
		)
		button.name = "Locate_" + role
		sites.add_child(button)
	var production: HBoxContainer = HBoxContainer.new()
	add_child(production)
	_batches = SpinBox.new()
	_batches.min_value = 1
	_batches.max_value = 15
	_batches.value = 1
	_batches.custom_minimum_size.x = 100
	production.add_child(_label(tr("transport.batches"), "Caption"))
	production.add_child(_batches)
	_buttons["cut"] = _button("transport.cut", func(): _act("work", "cut", int(_batches.value)))
	_buttons["saw"] = _button("transport.saw", func(): _act("work", "saw", int(_batches.value)))
	for kind: String in ["cut", "saw"]:
		_buttons[kind].name = "Work_" + kind
		production.add_child(_buttons[kind])
	var shipping: HBoxContainer = HBoxContainer.new()
	add_child(shipping)
	_leg = OptionButton.new()
	_leg.add_item(tr("transport.leg.wood"))
	_leg.add_item(tr("transport.leg.planks"))
	shipping.add_child(_leg)
	_mode = OptionButton.new()
	_mode.add_item(tr("transport.mode.land"))
	_mode.add_item(tr("transport.mode.boat"))
	shipping.add_child(_mode)
	_amount = SpinBox.new()
	_amount.min_value = 1
	_amount.max_value = 3
	_amount.value = 1
	_amount.custom_minimum_size.x = 100
	shipping.add_child(_amount)
	_buttons["dispatch"] = _button("transport.dispatch", func(): _act("dispatch", resource(), int(_amount.value), mode()))
	_buttons["dispatch"].name = "Dispatch"
	shipping.add_child(_buttons["dispatch"])
	_route = _label("", "Caption")
	add_child(_route)
	_forecast = _label("", "Caption")
	add_child(_forecast)
	var ports: HBoxContainer = HBoxContainer.new()
	add_child(ports)
	for role: String in TransportGame.ROLES:
		var button: Button = _button("transport.site." + role, _act.bind("port", role))
		button.name = "Dock_" + role
		_ports[role] = button
		ports.add_child(button)
	_buttons["claim"] = _button("transport.claim", func(): _act("claim", "", int(_amount.value)))
	_buttons["claim"].name = "Claim"
	add_child(_buttons["claim"])
	_error = _label("", "Caption")
	add_child(_error)
	add_child(_label(tr("transport.help"), "Caption"))
	_queue = VBoxContainer.new()
	add_child(_queue)
	_batches.value_changed.connect(func(_value: float): _update_plan())
	_amount.value_changed.connect(func(_value: float): _update_plan())
	_mode.item_selected.connect(func(_index: int):
		_amount.max_value = int(TransportGame.config()["modes"][mode()]["capacity"])
		_update_plan()
	)
	_leg.item_selected.connect(func(_index: int): _update_plan())
	refresh()


func mode() -> String:
	return "land" if _mode == null or _mode.selected == 0 else "boat"


func resource() -> String:
	return "wood" if _leg == null or _leg.selected == 0 else "planks"


func _act(action: String, kind: String = "", amount: int = 1, route_mode: String = "land", id: int = -1) -> void:
	_last_error = session.edit_transport(action, kind, amount, route_mode, id)
	changed.emit()


func refresh() -> void:
	if _stock == null:
		return
	for child: Node in _queue.get_children():
		_queue.remove_child(child)
		child.queue_free()
	if session == null or session.year.is_empty():
		_stock.text = tr("transport.no_run")
		for button: Button in _buttons.values():
			button.disabled = true
		for button: Button in _ports.values():
			button.disabled = true
		return
	var t: Dictionary = session.transport
	var ledger: Dictionary = TransportGame.ledger(session.model())
	var inv: Dictionary = t["inventory"]
	_stock.text = tr("transport.stock") % [int(inv["source"]["wood"]), int(inv["mill"]["wood"]), int(inv["mill"]["planks"]), int(inv["store"]["planks"]), int(t["claimed"])]
	_stock.text += "\n" + tr("transport.ledger") % [int(ledger["forest_reserved"]), int(ledger["wood_reserved"]), int(ledger["wood_transit"]), int(ledger["processing"]), int(ledger["planks_reserved"]), int(ledger["planks_transit"]), TransportGame.free_workers(session.model())]
	for role: String in TransportGame.ROLES:
		_ports[role].text = tr("transport.port") % [tr("transport.short." + role), tr("transport.open" if t["ports"][role] else "transport.closed")]
		_ports[role].disabled = session.year["outcome"] != "running"
	for field: String in ["work", "shipments"]:
		for job: Dictionary in t[field]:
			var text: String
			if field == "work":
				text = tr("transport.work_item") % [tr("transport." + String(job["kind"])), int(job["batches"]), int(job["progress"]), int(job["duration"]), tr(TransportGame.work_status(session.model(), job))]
			else:
				var tile: Dictionary = session.year["board"]["tiles"][job["current"]]
				text = tr("transport.shipment") % [int(job["id"]), tr("daily.resource." + String(job["resource"])), int(job["amount"]), tr("transport.mode." + String(job["mode"])), int(tile["q"]), int(tile["r"]), tr(TransportGame.shipment_status(session.model(), job))]
			_queue.add_child(_label(text))
			var row: HBoxContainer = HBoxContainer.new()
			_queue.add_child(row)
			var pause: Button = _button("daily.resume" if job["paused"] else "daily.pause", _act.bind("pause", "", 1, "land", int(job["id"])))
			pause.name = "Pause_" + str(job["id"])
			row.add_child(pause)
			var cancel: Button = _button("transport.return" if field == "shipments" and job["loaded"] else "daily.cancel", _act.bind("cancel", "", 1, "land", int(job["id"])))
			cancel.name = "Cancel_" + str(job["id"])
			row.add_child(cancel)
			pause.disabled = session.year["outcome"] != "running"
			cancel.disabled = pause.disabled
	if t["work"].is_empty() and t["shipments"].is_empty():
		_queue.add_child(_label(tr("daily.empty_queue"), "Caption"))
	if not prediction.is_empty():
		var future: Dictionary = prediction["transport"]
		var account: Dictionary = TransportGame.ledger(prediction)
		_forecast.text = tr("transport.preview") % [int(account["wood_reserved"]), int(account["wood_transit"]), int(account["planks_transit"]), int(future["inventory"]["store"]["planks"])]
	_error.text = tr(_last_error) if not _last_error.is_empty() else ""
	_update_plan()


func _update_plan() -> void:
	if session == null or session.year.is_empty() or _amount == null:
		return
	for kind: String in ["cut", "saw"]:
		var error: String = TransportGame.order_work(session.model().duplicate(true), kind, int(_batches.value))
		_buttons[kind].disabled = not error.is_empty()
		_buttons[kind].tooltip_text = tr(error) if not error.is_empty() else ""
	var error: String = TransportGame.dispatch(session.model().duplicate(true), resource(), int(_amount.value), mode())
	_buttons["dispatch"].disabled = not error.is_empty()
	_buttons["dispatch"].tooltip_text = tr(error) if not error.is_empty() else ""
	_buttons["claim"].disabled = session.year["outcome"] != "running" or int(_amount.value) > int(session.transport["inventory"]["store"]["planks"])
	var origin: String = "source" if resource() == "wood" else "mill"
	var target: String = "mill" if resource() == "wood" else "store"
	var path: Array[int] = TransportGame.route(session.model(), int(session.transport["sites"][origin]), int(session.transport["sites"][target]), mode())
	var policy: Dictionary = TransportGame.config()["modes"][mode()]
	_route.text = tr("transport.route") % [tr("transport.short." + origin), tr("transport.short." + target), tr("transport.mode." + mode()), int(policy["capacity"]), ceili(float(maxi(0, path.size() - 1)) / float(policy["speed"]))]
	if path.is_empty():
		_route.text += "\n" + tr("transport.status.blocked")
	route_changed.emit()


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
