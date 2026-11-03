extends SceneTree
## A complete year through GUI mouse events. Policy plans only on a copy.

class MenuBoot extends "res://ui/boot.gd":
	func _ready() -> void:
		pass

var _screen: YearScreen
var _checks: Array = []
var _out: String = ""
var _language: String = "en"
var _captured: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, name: String) -> void:
	_checks.append({"name": name, "passed": condition})
	if not condition:
		printerr("FAIL " + name)


func _frames(count: int = 2) -> void:
	for index: int in range(count):
		await process_frame


func _click_at(point: Vector2) -> void:
	point *= Vector2(root.size) / root.get_visible_rect().size
	Input.warp_mouse(point)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await _frames(1)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(1)


func _click(control: Control) -> void:
	if control == null:
		_check(false, "requested GUI control exists")
		return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _frames()
	_check(control.is_visible_in_tree(), "control visible: " + control.name)
	var point: Vector2 = control.get_global_rect().get_center()
	var window: Window = control.get_window()
	if window != root:
		point += Vector2(window.position)
	await _click_at(point)


func _command(command: Dictionary) -> void:
	if command["action"] == "cancel":
		_screen._tabs.current_tab = 1
		await _frames()
		await _click(_screen._queue.find_child("CancelTile_" + str(command["tile"]), true, false))
		return
	if command["action"] == "learn":
		_screen._tabs.current_tab = 2
		await _frames()
		await _click(_screen._research[command["id"]])
		return
	_screen._tabs.current_tab = 0
	var id: String = command["id"]
	var group: String = "build" if id.begins_with("build_") or id == "upgrade_house" else ("food" if id in ["forage", "fish", "plant_paddy", "harvest"] else ("materials" if id.begins_with("gather_") or id in ["saw_planks", "fire_bricks"] else "land"))
	_screen._group.select(YearScreen.GROUPS.find(group))
	_screen._group.item_selected.emit(_screen._group.selected)
	for index: int in range(_screen._action.item_count):
		if _screen._action.get_item_metadata(index) == id:
			_screen._action.select(index)
			_screen._action.item_selected.emit(index)
			break
	_screen._repeat.button_pressed = bool(command["repeat"])
	_screen._batches.value = int(command["batches"])
	await _frames()
	await _click_at(_screen.board.get_global_position() + _screen.board.center_of(int(command["tile"])))
	await _frames()
	_check(_screen.selected == int(command["tile"]), "hex selected: " + id)
	_check(not _screen._order_button.disabled, "legal order: " + id)
	await _click(_screen._order_button)


func _shot(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, "screenshot " + name)


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out = arg.trim_prefix("--out-dir=")
		if arg.begins_with("--lang="):
			_language = arg.trim_prefix("--lang=")
	if DisplayServer.get_name() == "headless" or not _out.is_absolute_path() or _language not in ["th", "en"]:
		printerr("Use a native display, absolute --out-dir, and --lang=th|en.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Localization.setup(_language)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var normal: String = _out.path_join("normal.json")
	var prototype: String = _out.path_join("prototype.json")
	SaveIO.save(GameFlow.new_game({"seed": 73}), normal)
	var file: FileAccess = FileAccess.open(prototype, FileAccess.WRITE)
	file.store_string(JSON.stringify(DailyCheckpoint.envelope(DailyProduction.new_state())))
	file.close()
	var normal_bytes: PackedByteArray = FileAccess.get_file_as_bytes(normal)
	var prototype_bytes: PackedByteArray = FileAccess.get_file_as_bytes(prototype)
	var path: String = _out.path_join("year.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_screen = YearScreen.new()
	_screen.session = YearSession.new()
	_screen.session.save_path = path
	root.add_child(_screen)
	await _frames(10)
	await _shot("initial-" + _language)
	var snapshot: Dictionary = _screen.session.year.duplicate(true)
	await _click(_screen._preview)
	_check(_screen.session.year == snapshot, "risk preview is read only")
	var iterations: int = 0
	while _screen.session.year["outcome"] == "running" and iterations < 500:
		var planned: Dictionary = _screen.session.year.duplicate(true)
		var commands: Array = []
		YearStrategy.plan(planned, true, commands)
		for command: Dictionary in commands:
			await _command(command)
		_check(_screen.session.year == planned, "GUI orders match plan day %d" % int(planned["day"]))
		if _screen.session.year != planned:
			break
		await create_timer(0.41).timeout
		await _click(_screen._time_buttons[2])
		var day: int = int(_screen.session.year["day"])
		if iterations == 0:
			await _click(_screen._time_buttons[2])
			_check(int(_screen.session.year["day"]) == day, "burst advance is ignored")
		for milestone: int in [120, 180, 242, 300, 365]:
			if day >= milestone and milestone not in _captured:
				_captured.append(milestone)
				await _shot("day-%d-%s" % [day, _language])
				var loaded: YearSession = YearSession.new()
				loaded.save_path = path
				_check(loaded.load_year() == "", "reload milestone %d" % milestone)
				_check(loaded.year == _screen.session.year, "exact milestone %d" % milestone)
		iterations += 1
	_check(int(_screen.session.year["day"]) == 365, "full 365 days reached")
	_check(_screen.session.year["outcome"] == "won", "year completed through GUI commands")
	_check(int(_screen.session.year["stats"]["planks"]) >= 8, "production challenge completed")
	_check("housing2" in _screen.session.year["research"], "rewards used for advanced protection")
	_check(int(_screen.session.year["stats"]["damage"]) > 0, "real flood damage handled")
	_check(FileAccess.get_file_as_bytes(normal) == normal_bytes, "normal checkpoint unchanged")
	_check(FileAccess.get_file_as_bytes(prototype) == prototype_bytes, "prototype checkpoint unchanged")
	var completed: Dictionary = _screen.session.year.duplicate(true)
	await _click(_screen._new_button)
	await _frames()
	_check(_screen._restart.visible, "new year confirmation visible")
	await _click(_screen._restart.get_cancel_button())
	_check(_screen.session.year == completed, "cancel new year preserves completed run")
	await _click(_screen._new_button)
	_screen._seed.text = "73"
	_screen._goal.select(2)
	await _shot("new-year-" + _language)
	await _click(_screen._restart.get_ok_button())
	_check(_screen.session.year["day"] == 0, "new year starts at day zero")
	_check(_screen.session.year["board"]["seed"] == "73", "new year uses chosen seed")
	_check(_screen.session.year["goal"] == "forest", "new year uses chosen goal")
	_screen.free()
	var boot: MenuBoot = MenuBoot.new()
	boot._save_path = normal
	boot._language = _language
	root.add_child(boot)
	boot._show_menu()
	await _frames()
	await _click(boot._screen.find_child("FullYearGame", true, false))
	_check(boot._screen is YearScreen, "menu opens full year")
	_check(FileAccess.get_file_as_bytes(normal) == normal_bytes, "menu keeps normal checkpoint")
	boot.free()
	var failed: int = 0
	for check: Dictionary in _checks:
		if not check["passed"]:
			failed += 1
	file = FileAccess.open(_out.path_join("report-" + _language + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"language": _language, "checks": _checks, "failed": failed, "input": "GUI mouse events; form fields populated from a reference policy on a copy"}, "  "))
	file.close()
	print("Year native: %d checks, %d failed" % [_checks.size(), failed])
	quit(0 if failed == 0 else 1)
