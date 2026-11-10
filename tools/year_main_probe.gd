extends SceneTree
## Isolated native checks for the main 365-day screen; no player checkpoint I/O.

var output: String = ""
var language: String = "en"


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
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
	var error: String = session.start_campaign(42, "forest", "water", "fisher", 5)
	if not error.is_empty():
		printerr(error)
		quit(1)
		return
	var screen: YearScreen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	await _capture("year-main-" + language)
	var before: Dictionary = session.year.duplicate(true)
	var settings: Dictionary = GamePreferences.read()
	GamePreferences.write({"confirm_unused_labor": true})
	await _click(screen._time_buttons[0])
	var passed: bool = screen._advance_confirmation.visible and session.year == before
	await _capture("year-confirm-" + language)
	await _click(screen._advance_confirmation.get_ok_button())
	passed = passed and int(session.year["day"]) == 1 and session.daily_history.size() == 1
	# Select the history tab using the native TabBar hit target.
	var tabbar: TabBar = screen._tabs.get_tab_bar()
	var tab_rect: Rect2 = tabbar.get_tab_rect(5)
	await _click_at(tabbar.global_position + tab_rect.get_center())
	passed = passed and screen._tabs.current_tab == 5 and not screen._history.text.is_empty()
	await _capture("year-history-" + language)
	screen.show_new_year()
	await _capture("year-setup-" + language)
	passed = passed and screen._leader.is_visible_in_tree() and screen._difficulty.is_visible_in_tree()
	GamePreferences.write(settings)
	print("YEAR MAIN NATIVE ", language, ": ", "PASS" if passed else "FAIL")
	screen.free()
	quit(0 if passed else 1)
