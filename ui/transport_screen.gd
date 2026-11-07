class_name TransportScreen
extends YearScreen

var transport_panel: TransportPanel
var transport_prediction: Dictionary = {}


func _ready() -> void:
	if session == null:
		session = TransportSession.new()
	super._ready()
	var tab: VBoxContainer = _tab(_tabs, "transport.tab")
	transport_panel = TransportPanel.new()
	transport_panel.session = session as TransportSession
	transport_panel.changed.connect(_refresh)
	transport_panel.route_changed.connect(_update_route)
	transport_panel.site_requested.connect(select_tile)
	tab.add_child(transport_panel)
	_tabs.current_tab = _tabs.get_tab_count() - 1
	_refresh()


func _title_key() -> String:
	return "transport.title"


func _make_board() -> YearBoard:
	return TransportBoard.new()


func _preview_year() -> Dictionary:
	transport_prediction = TransportGame.preview((session as TransportSession).model())["state"]
	return transport_prediction["year"]


func _worker_count() -> int:
	return YearGame.workers(session.year) + TransportGame.workers((session as TransportSession).model())


func _refresh() -> void:
	super._refresh()
	if transport_panel != null:
		transport_panel.prediction = transport_prediction
		transport_panel.refresh()
	_update_route()


func _refresh_selection() -> void:
	super._refresh_selection()
	if session == null or session.year.is_empty() or _order_button == null or selected < 0 or action_id().is_empty():
		return
	var transport_session: TransportSession = session as TransportSession
	var stop_at: int = int(_stop_at.value) if _policy.visible and _stop_at.editable else 0
	var reserve: int = int(_reserve.value) if _policy.visible and _reserve.editable else 0
	var error: String = transport_session.check_year_order(action_id(), selected, int(_batches.value), _repeat.button_pressed, _direction.selected, stop_at, reserve)
	_order_button.disabled = not error.is_empty()
	_reason.text = tr(error) if not error.is_empty() else ""
	var filtered: Array[int] = []
	for index: int in board.targets:
		if transport_session.check_year_order(action_id(), index, int(_batches.value), _repeat.button_pressed, _direction.selected, stop_at, reserve).is_empty():
			filtered.append(index)
	board.targets = filtered


func _update_route() -> void:
	if board == null or session == null:
		return
	var transport_board: TransportBoard = board as TransportBoard
	transport_board.transport_model = {} if session.year.is_empty() else (session as TransportSession).model()
	if transport_panel != null:
		transport_board.route_mode = transport_panel.mode()
		transport_board.route_resource = transport_panel.resource()
	transport_board.queue_redraw()
