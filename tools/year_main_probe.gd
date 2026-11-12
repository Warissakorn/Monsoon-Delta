extends SceneTree
## Isolated native checks for the main 365-day screen; no player checkpoint I/O.

var developed: bool = false
var output: String = ""
var language: String = "en"
var checks: Array[Dictionary] = []


func _check(condition: bool, label: String) -> void:
	checks.append({"check": label, "passed": condition})
	if not condition:
		printerr("FAIL " + label)


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--developed":
			developed = true
		if argument.begins_with("--out-dir="):
			output = argument.trim_prefix("--out-dir=")
		if argument.begins_with("--lang="):
			language = argument.trim_prefix("--lang=")
	call_deferred("_run")


func _click_at(point: Vector2) -> void:
	point *= Vector2(root.size) / root.get_visible_rect().size
	Input.warp_mouse(point)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _click(control: Control) -> void:
	# Newly shown forms need their layout before scrolling to the target.
	await process_frame
	await process_frame
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await process_frame
	await process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	if control.get_window() != root:
		point += Vector2(control.get_window().position)
	await _click_at(point)


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))


func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Use a rendering display and --out-dir= with an isolated directory.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Localization.setup(language)
	root.size = Vector2i(1280, 720)
	var session: YearSession = YearSession.new()
	session.save_path = output.path_join("probe-year.json")
	var error: String = session.start_campaign(42, "forest", "water", "farmer" if developed else "fisher", 0 if developed else 5)
	if not error.is_empty():
		printerr(error)
		quit(1)
		return
	if developed:
		while int(session.year["day"]) < 244 and session.year["outcome"] == "running":
			YearProjectStrategy.plan(session.year)
			session.advance_year(mini(7, 244 - int(session.year["day"])))
	var screen: YearScreen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	await _capture("year-main-" + language)
	if developed:
		var before: Dictionary = session.year.duplicate(true)
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(session.save_path)
		await _capture("year-developed-" + language)
		var passed: bool = int(session.year["day"]) == 244 and YearCheckpoint.valid(session.year) and session.year == before and FileAccess.get_file_as_bytes(session.save_path) == saved
		print("YEAR DEVELOPED NATIVE ", language, ": ", "PASS" if passed else "FAIL")
		screen.free()
		quit(0 if passed else 1)
		return
	_check(screen.board is YearBoard3D, "main board uses shared 3D village renderer")
	var board: YearBoard3D = screen.board as YearBoard3D
	var original: Dictionary = session.year.duplicate(true)
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(session.save_path)
	board.set_reduced_motion(true)
	board.rotate_view(1)
	board.zoom_by(1.2)
	board.focus_selected()
	board.toggle_labels()
	await _capture("year-camera-" + language)
	_check(session.year == original and FileAccess.get_file_as_bytes(session.save_path) == save_bytes, "camera and levels do not change state or checkpoint")
	board.fit_map()
	screen._group.select(2)
	screen._populate_actions()
	for index: int in range(screen._action.item_count):
		if screen._action.get_item_metadata(index) == "build_sawmill":
			screen._action.select(index)
	screen._refresh_selection()
	var target: int = YearStrategy.target(session.year, "build_sawmill")
	await process_frame
	await _click_at(board.global_position + board.center_of(target))
	_check(screen.selected == target, "ray pick selects real work tile after rotation")
	await _click(screen._order_button)
	_check(session.year["jobs"].size() == 1, "native order reserves a real job")
	_check(not screen._resource_feedback.last_changes.is_empty(), "real order produces resource feedback")
	var ordered: Dictionary = session.year.duplicate(true)
	await _click(screen._undo)
	_check(session.year == original, "native undo restores exact order inputs")
	await _click(screen._redo)
	_check(session.year == ordered, "native redo restores exact job and reservations")
	await _click(screen._preview)
	_check(board.village._prediction.is_empty(), "native preview toggle clears forecast overlays")
	await _click(screen._preview)
	_check(not board.village._prediction.is_empty(), "preview shows next-day water")
	_check(not board.forecast_flow.flow_edges.is_empty(), "preview uses recorded water transfers")
	await _capture("year-order-" + language)
	var before: Dictionary = session.year.duplicate(true)
	var settings: Dictionary = GamePreferences.read()
	GamePreferences.write({"confirm_unused_labor": true})
	await _click(screen._time_buttons[0])
	_check(screen._advance_confirmation.visible and session.year == before, "day confirmation does not advance simulation")
	await _capture("year-confirm-" + language)
	await _click(screen._advance_confirmation.get_ok_button())
	_check(int(session.year["day"]) == 1 and session.daily_history.size() == 1, "native confirmation advances exactly one day")
	_check(board.village._flow_view.is_showing_actual(), "committed day shows its actual water flow")
	# Select the history tab using the native TabBar hit target.
	var tabbar: TabBar = screen._tabs.get_tab_bar()
	var tab_rect: Rect2 = tabbar.get_tab_rect(5)
	await _click_at(tabbar.global_position + tab_rect.get_center())
	_check(screen._tabs.current_tab == 5 and not screen._history.text.is_empty(), "native history tab shows committed resource totals")
	await _capture("year-history-" + language)
	screen.show_new_year()
	await _capture("year-setup-" + language)
	_check(screen._leader.is_visible_in_tree() and screen._difficulty.is_visible_in_tree(), "setup fields visible")
	GamePreferences.write(settings)
	var passed: bool = checks.all(func(check: Dictionary): return check["passed"])
	var file: FileAccess = FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"language": language, "checks": checks, "passed": passed}, "  "))
	file.close()
	print("YEAR MAIN NATIVE ", language, ": ", "PASS" if passed else "FAIL", " ", checks.size(), " checks")
	screen.free()
	quit(0 if passed else 1)
