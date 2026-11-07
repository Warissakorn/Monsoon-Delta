extends SceneTree
## Native transport pilot: real GUI actions on an authored new pilot, no state fixtures.

class MenuBoot extends "res://ui/boot.gd":
	func _ready() -> void:
		pass

var _screen: TransportScreen
var _checks: Array = []
var _out: String = ""
var _language: String = "en"
var _session: TransportSession


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


func _shot(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, "screenshot " + name)


func _day() -> void:
	var predicted: Dictionary = TransportGame.preview(_session.model())["state"]
	await create_timer(0.42).timeout
	await _click(_screen._time_buttons[0])
	_check(_session.model() == predicted, "GUI day matches combined preview exactly")
	_check(_session.last_save_error.is_empty(), "day checkpoint succeeds")


func _reload() -> void:
	var loaded: TransportSession = TransportSession.new()
	loaded.save_path = _session.save_path
	_check(loaded.load_year().is_empty(), "reload cargo checkpoint")
	_check(loaded.model() == _session.model(), "cargo, nested water and RNG load exactly")


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
	# Only isolated XDG paths: sentinel runs use their real default filenames.
	SaveIO.save(GameFlow.new_game({"seed": 73}), SaveIO.DEFAULT_PATH)
	var year: YearSession = YearSession.new()
	year.start_year(73)
	var file: FileAccess = FileAccess.open(DailySession.DAILY_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(DailyCheckpoint.envelope(DailyProduction.new_state())))
	file.close()
	var sentinels: Dictionary = {}
	for path: String in [SaveIO.DEFAULT_PATH, DailySession.DAILY_PATH, YearSession.YEAR_PATH]:
		sentinels[path] = FileAccess.get_file_as_bytes(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TransportSession.TRANSPORT_PATH))
	var boot: MenuBoot = MenuBoot.new()
	boot._save_path = SaveIO.DEFAULT_PATH
	boot._language = _language
	root.add_child(boot)
	boot._show_menu()
	await _frames(10)
	await _shot("menu-" + _language)
	await _click(boot._screen.find_child("TransportPilot", true, false))
	_check(boot._screen is TransportScreen, "menu opens separate transport pilot")
	_screen = boot._screen as TransportScreen
	if _screen == null:
		quit(1)
		return
	_session = _screen.session as TransportSession
	var panel: TransportPanel = _screen.transport_panel
	await _shot("initial-" + _language)
	var before: Dictionary = _session.model().duplicate(true)
	await _click(_screen._preview)
	await _click(panel.find_child("Locate_mill", true, false))
	_check(_screen.selected == int(_session.transport["sites"]["mill"]), "locate mill selects correct site")
	_check(_session.model() == before, "preview and locate are read only")
	panel._batches.value = 2
	await _click(panel._buttons["cut"])
	_check(_session.transport["work"].size() == 1, "cut order reserves finite forest")
	await _click(_screen._undo)
	_check(_session.model() == before, "GUI undo restores year and reservations")
	await _click(_screen._redo)
	_check(_session.transport["work"].size() == 1, "GUI redo restores production order")
	await _day()
	await _day()
	_check(_session.transport["inventory"]["source"]["wood"] == 2, "cut output remains local")
	panel._mode.select(1)
	panel._mode.item_selected.emit(1)
	panel._amount.value = 2
	await _click(panel._ports["mill"])
	_check(not _session.transport["ports"]["mill"], "mill dock closes through its own button")
	await _click(panel._buttons["dispatch"])
	await _day()
	_check(TransportGame.ledger(_session.model())["wood_reserved"] == 2, "closed dock holds unloaded reservation")
	_check(not _session.transport["shipments"][0]["loaded"], "blocked shipment never loads")
	await _shot("blocked-" + _language)
	await _click(panel._ports["mill"])
	await _day() # Load.
	await _day() # Move two canal edges.
	_check(TransportGame.ledger(_session.model())["wood_transit"] == 2, "cargo remains in transit at a real canal cell")
	_reload()
	await _shot("transit-" + _language)
	await _click(panel.find_child("Cancel_2", true, false))
	_check(_session.transport["shipments"][0]["returning"], "loaded cancellation requests physical return")
	_check(_session.transport["inventory"]["source"]["wood"] == 2, "return request does not teleport cargo")
	await _day()
	_check(_session.transport["inventory"]["source"]["wood"] == 4, "boat returns reserved goods to source")
	await _click(panel._buttons["dispatch"])
	for index: int in range(3):
		await _day()
	_check(_session.transport["inventory"]["mill"]["wood"] == 2, "boat delivers raw wood to mill")
	panel._batches.value = 1
	await _click(panel._buttons["saw"])
	await _day()
	await _day()
	_check(_session.transport["inventory"]["mill"]["planks"] == 1, "mill consumes two wood per plank")
	_check(_session.year["resources"]["planks"] == before["year"]["resources"]["planks"], "local plank is not yet available to village")
	panel._leg.select(1)
	panel._leg.item_selected.emit(1)
	panel._mode.select(0)
	panel._mode.item_selected.emit(0)
	panel._amount.value = 1
	await _click(panel._buttons["dispatch"])
	await _day()
	await _day()
	_check(_session.transport["inventory"]["store"]["planks"] == 1, "land carrier delivers plank to store")
	await _click(panel._buttons["claim"])
	_check(_session.transport["claimed"] == 1, "warehouse claim recorded once")
	_check(_session.year["resources"]["planks"] == int(before["year"]["resources"]["planks"]) + 1, "warehouse claim becomes spendable village stock")
	_check(panel._buttons["claim"].disabled, "empty warehouse prevents a second claim")
	_check(TransportCheckpoint.valid(_session.model()), "final conserved model is checkpointable")
	_reload()
	await _shot("complete-" + _language)
	for path: String in sentinels:
		_check(FileAccess.get_file_as_bytes(path) == sentinels[path], "other default checkpoint unchanged: " + path)
	boot.free()
	var failed: int = 0
	for check: Dictionary in _checks:
		if not check["passed"]:
			failed += 1
	file = FileAccess.open(_out.path_join("report-" + _language + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"language": _language, "checks": _checks, "failed": failed, "input": "GUI mouse events; form quantities and route options populated directly; new authored pilot seed 42, no simulation fixtures"}, "  "))
	file.close()
	print("Transport native: %d checks, %d failed" % [_checks.size(), failed])
	quit(0 if failed == 0 else 1)
