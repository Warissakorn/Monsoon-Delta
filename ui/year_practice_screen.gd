class_name YearPracticeScreen
extends YearScreen
## The normal year UI on a detached practice session, with goals from committed actions.
signal quit_requested()
var _attempt: YearPracticeSession
var _restart_practice_dialog: ConfirmationDialog


func _ready() -> void:
	if not session is YearPracticeSession:
		session = YearPracticeSession.new()
		(session as YearPracticeSession).begin()
	_attempt = session as YearPracticeSession
	super._ready()
	_back_button.text = tr("yearpractice.leave")
	_save_button.hide()
	for connection: Dictionary in _new_button.pressed.get_connections():
		_new_button.pressed.disconnect(connection["callable"])
	_new_button.text = tr("yearpractice.restart")
	_restart_practice_dialog = ConfirmationDialog.new()
	_restart_practice_dialog.title = tr("yearpractice.restart")
	_restart_practice_dialog.dialog_text = tr("yearpractice.restart_confirm")
	_restart_practice_dialog.ok_button_text = tr("action.confirm")
	_restart_practice_dialog.cancel_button_text = tr("action.cancel")
	_restart_practice_dialog.confirmed.connect(_reset_practice)
	add_child(_restart_practice_dialog)
	_new_button.pressed.connect(func(): _restart_practice_dialog.popup_centered())
	_advice_text.max_lines_visible = 4
	_refresh()


func _title_key() -> String:
	return "yearpractice.title"


func _refresh() -> void:
	super._refresh()
	if _attempt == null:
		return
	var heading: Label = _advice_card.get_child(0).get_child(0) as Label
	heading.text = tr("yearpractice.step") % [mini(_attempt.step + 1, YearPracticeSession.STEPS.size()), YearPracticeSession.STEPS.size()]
	var key: String = "failed" if _attempt.failed else ("done" if _attempt.completed() else YearPracticeSession.STEPS[_attempt.step])
	_advice_text.text = tr("yearpractice." + key)
	_advice_button.text = tr("yearpractice.leave" if _attempt.completed() else "yearpractice.prepare")
	_advice_button.disabled = _attempt.failed
	for button: Button in _time_buttons:
		button.disabled = _attempt.step < 3 or _attempt.completed() or _attempt.failed
	_summary.text = tr("yearpractice.memory_only")
	_result_button.hide()


func _act_on_advice() -> void:
	if _attempt.completed():
		menu_requested.emit()
		return
	match _attempt.step:
		0:
			_select_action("forage")
			_repeat.button_pressed = true
			select_tile(_attempt.target())
			board.focus_selected()
		1: _undo.grab_focus()
		2: _redo.grab_focus()
		3: _time_buttons[0].grab_focus()
		4, 5:
			_queue_filter.select(0)
			_refresh_queue()
			_tabs.current_tab = 1
			selected = _attempt.forage_tile
			var button: Control = _queue.find_child("PauseTile_" + str(selected), true, false) as Control
			if button != null:
				button.grab_focus()
		6:
			_select_action("build_house")
			select_tile(_attempt.target())
			board.focus_selected()


func _request_advance(days: int) -> void:
	if _attempt.step < 3 or _attempt.completed() or _attempt.failed:
		return
	super._request_advance(days)


func _new_year() -> void:
	_reset_practice()


func _reset_practice() -> void:
	_attempt.begin()
	_log.clear()
	_latest_notice = ""
	_history_day = -1
	_history_view.clear()
	_history_return.hide()
	_clear_village_inspection()
	board.clear_feedback()
	_resource_feedback.clear()
	selected = session.year["structures"].find("hall")
	_last_advance = -1000
	_group.select(0)
	_repeat.set_pressed_no_signal(false)
	_batches.value = 1
	_stop_at.value = 0
	_reserve.value = 0
	_direction.select(0)
	_tabs.current_tab = 0
	_building_list.restore_draft({})
	_populate_actions()
	_refresh()
	board.fit_map()


func _unhandled_key_input(event: InputEvent) -> void:
	if _restart_practice_dialog != null and _restart_practice_dialog.visible:
		return
	super._unhandled_key_input(event)


func _process(delta: float) -> void:
	super._process(delta)
	if _restart_practice_dialog != null and _restart_practice_dialog.visible:
		board.set_suspended(true)


func request_quit() -> void:
	quit_requested.emit()


func _show_year_result() -> void:
	# A lesson result is separate from the year campaign score.
	pass
