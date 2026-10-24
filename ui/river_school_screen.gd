class_name RiverSchoolScreen
extends GameScreen
## Memory-only lessons reuse normal water, commands and presentation.

signal school_requested
signal lesson_requested(scenario_id: String)

var lesson: RiverSchoolRun
var hint_level: int = 0
var _hint_button: Button
var _school_modal_return: String = ""
var _hint_modal_return: String = ""
var _suspended_modal: Control
var _suspended_modal_content: VBoxContainer
var _suspended_confirmation: CheckBox
var _suspended_focus: Control


func _ready() -> void:
	if lesson == null or lesson.session == null or lesson.session.state == null:
		return
	session = lesson.session
	super._ready()


func _build_hud() -> void:
	super._build_hud()
	var goal_content: VBoxContainer = _goal_panel.get_child(0) as VBoxContainer
	var heading: HBoxContainer = goal_content.get_child(0) as HBoxContainer
	(heading.get_child(1) as Label).text = tr("school.title")
	_hint_button = _button(tr("school.hint") + " · F1", open_hint, "SchoolHint")
	_hint_button.focus_mode = Control.FOCUS_ALL
	_hint_button.theme_type_variation = "QuietButton"
	_hint_button.custom_minimum_size.y = 36
	(_advisor_panel.get_child(0) as VBoxContainer).add_child(_hint_button)


func refresh_state() -> void:
	super.refresh_state()
	_run_label.text = tr("school.title") + "\n" + tr("school." + lesson.scenario_id + ".name")
	_run_label.tooltip_text = tr("school.prepared_board")
	_time_label.text = tr("school.turn") % [tr("season.rain" if session.state.is_rain() else "season.dry"), mini(lesson.turns_resolved + 1, C.TURNS_PER_YEAR)]
	_survival_help.text = tr("school." + lesson.scenario_id + ".goal")
	_survival_progress.max_value = C.TURNS_PER_YEAR
	_survival_progress.value = lesson.turns_resolved
	_survival_progress.tooltip_text = tr("school.deadline")
	_end_button.disabled = _end_button.disabled or lesson.completed
	_hint_button.disabled = lesson.completed


func _refresh_save_status() -> void:
	_save_label.add_theme_color_override("font_color", Color(_colors.danger if not _preferences_error.is_empty() else _colors.muted))
	_save_label.text = tr(_preferences_error) if not _preferences_error.is_empty() else tr("school.no_checkpoint")


func _refresh_village_goal() -> void:
	_goal_panel.visible = true
	var progress: Dictionary = lesson.progress()
	_goal_label.text = "\n".join(PackedStringArray([
		tr("school." + lesson.scenario_id + ".goal"),
		tr("school.deadline"),
		tr("school.progress") % [int(progress["turns"]), int(progress["rice_food"]), int(progress["fish_food"])],
		tr("school." + lesson.scenario_id + ".mastery"),
	]))
	for child: Node in _goal_bars.get_children():
		_goal_bars.remove_child(child)
		child.queue_free()
	_goal_progress_bar("next", int(progress["turns"]), C.TURNS_PER_YEAR)


func _update_command_status() -> void:
	if command_mode.is_empty() and wheel_origin == BoardView.NO_COORD:
		_status_label.text = tr("school.deadline")
	else:
		super._update_command_status()


func request_end_turn() -> void:
	if lesson.completed:
		return
	super.request_end_turn()


func _finish_turn() -> void:
	if lesson.completed:
		return
	var report: TurnReport = lesson.advance_turn()
	if report == null:
		return
	wheel_origin = BoardView.NO_COORD
	refresh_state()
	board.show_actual_flow(report)
	board.show_turn_activity(report)
	board.show_harvest_activity(session.last_harvest_food_by_tile)
	if lesson.completed:
		_show_result()
	else:
		_show_turn_feedback(report)


func _show_harvest() -> void:
	_show_result()


func _show_game_over() -> void:
	_show_result()


func continue_harvest() -> void:
	# The real state remains at its harvest; lessons do not start year two.
	return


func _show_result() -> void:
	var result: Dictionary = lesson.result()
	_open_modal("school_result", tr("school.passed" if lesson.passed else "school.failed"))
	_modal_content.add_child(_label(tr("school." + lesson.scenario_id + ".name"), 22, true))
	var details: VBoxContainer = _school_scroll("SchoolResultDetails", 210)
	for key: String in result["reasons"]:
		details.add_child(_label(tr(key), 18))
	var harvest: Dictionary = result["harvest"]
	if not harvest.is_empty():
		details.add_child(_label(tr("school.result_rice") % int(harvest["paddy_food"]), 18))
		details.add_child(_label(tr("school.result_migration") % [int(harvest["left_hunger"]), int(harvest["left_housing"])], 18))
		details.add_child(_label(tr("school.result_population") % int(harvest["population_after"]), 18))
	details.add_child(_label(tr("school.result_fish") % lesson.fish_food, 18))
	if lesson.passed:
		details.add_child(_label(tr("school.mastery_earned" if lesson.mastered else "school.mastery_not_earned"), 20))
		details.add_child(_label(tr("school." + lesson.scenario_id + ".mastery"), 18, true))
	_add_modal_button(tr("school.retry"), retry_lesson, "SchoolRetry", true)
	if lesson.passed and lesson.scenario_id == "river_school_01":
		_add_modal_button(tr("school.next_lesson"), func(): lesson_requested.emit("river_school_03"), "SchoolNext")
	_add_modal_button(tr("school.choose"), _choose_school, "SchoolChoose")
	_add_modal_button(tr("action.history"), open_turn_history, "SchoolHistory")
	_add_modal_button(tr("action.menu"), _return_menu, "SchoolMenu")


func _school_scroll(node_name: String, height: float) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = node_name + "Scroll"
	scroll.custom_minimum_size = Vector2(704, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_modal_content.add_child(scroll)
	var details: VBoxContainer = VBoxContainer.new()
	details.name = node_name
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	return details


func open_hint() -> void:
	if lesson.completed or modal_kind not in ["", "pause", "school_hint"]:
		return
	if modal_kind != "school_hint":
		_hint_modal_return = modal_kind
	hint_level = maxi(1, hint_level)
	_render_hint()


func _render_hint() -> void:
	_open_modal("school_hint", tr("school.hint_title") % hint_level)
	_modal_content.add_child(_label(tr("school.hints_optional"), 18, true))
	var details: VBoxContainer = _school_scroll("SchoolHintDetails", 260)
	details.add_child(_label(tr("school." + lesson.scenario_id + ".hint%d" % hint_level)))
	if hint_level == 3:
		var solutions: Array[Dictionary] = RiverSchoolFixtures.solutions(lesson.scenario_id)
		if not solutions.is_empty():
			var turns: Array = solutions[0]["turns"]
			for turn_index: int in range(turns.size()):
				details.add_child(_label(tr("school.solution_turn") % (turn_index + 1), 20))
				if turns[turn_index].is_empty():
					details.add_child(_label(tr("school.solution_wait"), 18, true))
				for command: Dictionary in turns[turn_index]:
					var coord: Vector2i = command["coord"]
					details.add_child(_label(tr("school.solution_command") % [tr("cmd." + String(command["id"]) + ".name"), coord.x, coord.y], 18, true))
	if hint_level < 3:
		_add_modal_button(tr("school.next_hint"), _next_hint, "SchoolNextHint")
	_add_modal_button(tr("school.close"), _close_school_modal, "SchoolCloseHint", true)


func _next_hint() -> void:
	if modal_kind != "school_hint":
		return
	hint_level = mini(3, hint_level + 1)
	_render_hint()


func _close_school_modal() -> void:
	if modal_kind == "school_exit":
		close_modal()
		modal_kind = _school_modal_return
		_school_modal_return = ""
		_modal = _suspended_modal
		_modal_content = _suspended_modal_content
		_skip_confirmation = _suspended_confirmation
		_suspended_modal = null
		_suspended_modal_content = null
		_suspended_confirmation = null
		if _modal != null:
			_modal.show()
			board.set_activity_paused(true)
			if is_instance_valid(_suspended_focus) and _modal.is_ancestor_of(_suspended_focus):
				_suspended_focus.grab_focus()
		_suspended_focus = null
		return
	var previous: String = _hint_modal_return
	if modal_kind == "school_hint":
		_hint_modal_return = ""
	close_modal()
	if lesson.completed:
		_show_result()
	elif previous == "pause":
		open_pause()


func retry_lesson() -> void:
	if not lesson.retry():
		return
	_discard_suspended_modal()
	close_modal()
	session = lesson.session
	hint_level = 0
	_school_modal_return = ""
	_hint_modal_return = ""
	command_mode = ""
	wheel_origin = BoardView.NO_COORD
	hovered_coord = BoardView.NO_COORD
	_inspection_focus = BoardView.NO_COORD
	_history_return = ""
	board.clear_activity()
	refresh_state()


func _restart() -> void:
	retry_lesson()


func open_pause() -> void:
	if lesson.completed:
		_show_result()
		return
	if not modal_kind.is_empty():
		return
	_open_modal("pause", tr("pause.title"))
	_modal_content.add_child(_label(tr("school." + lesson.scenario_id + ".name"), 22))
	_modal_content.add_child(_label(tr("school.no_checkpoint"), 18, true))
	_motion_toggle = CheckBox.new()
	_motion_toggle.name = "ReducedMotion"
	_motion_toggle.text = tr("pause.reduced_motion")
	_motion_toggle.tooltip_text = tr("pause.reduced_motion_hint")
	_motion_toggle.set_pressed_no_signal(reduced_motion)
	_motion_toggle.toggled.connect(_on_motion_toggled)
	_modal_content.add_child(_motion_toggle)
	_motion_error = _label("", 18)
	_motion_error.visible = false
	_motion_error.add_theme_color_override("font_color", Color(_colors.danger))
	_modal_content.add_child(_motion_error)
	_add_modal_button(tr("action.resume"), close_modal, "Resume", true)
	_add_modal_button(tr("school.hint"), open_hint, "SchoolPauseHint")
	_add_modal_button(tr("action.history"), open_turn_history, "PauseHistory")
	_add_modal_button(tr("school.retry"), retry_lesson, "SchoolPauseRetry")
	_add_modal_button(tr("school.choose"), _choose_school, "SchoolPauseChoose")
	_add_modal_button(tr("action.menu"), _return_menu, "PauseMenu")


func _choose_school() -> void:
	_leave_game(func(): school_requested.emit())


func _leave_game(exit_action: Callable) -> void:
	if lesson.completed:
		exit_action.call()
		return
	if modal_kind == "school_exit":
		return
	_school_modal_return = modal_kind
	# Keep the interrupted dialog alive so cancel restores its exact history
	# selection, scroll, focus and unsaved confirmation checkbox. Rebuilding
	# only Pause or hints loses the other planning dialogs and their context.
	_suspended_modal = _modal
	_suspended_modal_content = _modal_content
	_suspended_confirmation = _skip_confirmation
	_suspended_focus = get_viewport().gui_get_focus_owner()
	if _suspended_modal != null:
		_suspended_modal.hide()
	_modal = null
	_open_modal("school_exit", tr("school.exit_title"))
	_modal_content.add_child(_label(tr("school.exit_body")))
	_add_modal_button(tr("school.leave"), _confirm_school_exit.bind(exit_action), "SchoolLeave")
	_add_modal_button(tr("action.resume"), _close_school_modal, "SchoolCancelLeave", true)


func _confirm_school_exit(exit_action: Callable) -> void:
	if modal_kind != "school_exit":
		return
	_discard_suspended_modal()
	exit_action.call()


func _discard_suspended_modal() -> void:
	if _suspended_modal != null:
		_suspended_modal.queue_free()
	_suspended_modal = null
	_suspended_modal_content = null
	_suspended_confirmation = null
	_suspended_focus = null
	_school_modal_return = ""


func open_turn_history() -> void:
	if modal_kind == "school_result":
		modal_kind = "harvest"
		super.open_turn_history()
		_history_return = "school_result"
	else:
		super.open_turn_history()


func close_turn_history() -> void:
	if modal_kind == "turn_history" and _history_return == "school_result":
		_history_return = ""
		close_modal()
		_show_result()
	else:
		super.close_turn_history()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1 and modal_kind.is_empty():
			open_hint()
			get_viewport().set_input_as_handled()
			return
		if modal_kind == "school_result":
			if event.physical_keycode == KEY_H:
				open_turn_history()
			get_viewport().set_input_as_handled()
			return
		if modal_kind in ["school_hint", "school_exit"]:
			if event.physical_keycode == KEY_ESCAPE:
				_close_school_modal()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)
