extends SceneTree
## godot --headless --path . --script tests/run_tests.gd -- --filter=hex


class TestErrorLogger extends Logger:
	# Godot can abort a dynamically called test method without throwing to its
	# caller. Observe the engine error stream so that this cannot become a PASS.
	var _mutex: Mutex = Mutex.new()
	var _errors: PackedStringArray = PackedStringArray()

	func _log_error(
		_function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		var detail: String = rationale if not rationale.is_empty() else code
		var message: String = "%s:%d: %s" % [file, line, detail]
		_mutex.lock()
		_errors.append(message)
		_mutex.unlock()


	func take_errors() -> PackedStringArray:
		_mutex.lock()
		var result: PackedStringArray = _errors
		_errors = PackedStringArray()
		_mutex.unlock()
		return result


var _error_logger: TestErrorLogger = TestErrorLogger.new()


func _initialize() -> void:
	OS.add_logger(_error_logger)
	call_deferred("_run")


func _print_failure(location: String, failures: PackedStringArray) -> void:
	var message: String = " | ".join(failures).replace("\n", " ").replace("\r", " ")
	print("FAIL %s: %s" % [location, message])


func _run() -> void:
	var filter: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--filter="):
			filter = argument.trim_prefix("--filter=")
	var files: Array[String] = []
	for filename: String in DirAccess.get_files_at("res://tests"):
		if not filename.begins_with("test_") or not filename.ends_with(".gd"):
			continue
		if filename in ["test_case.gd", "test_maps.gd"]:
			continue
		if filter.is_empty() or filename.contains(filter):
			files.append(filename)
	files.sort()
	var passed: int = 0
	var failed: int = 0
	var matched: int = 0
	for filename: String in files:
		var unassociated: PackedStringArray = _error_logger.take_errors()
		if not unassociated.is_empty():
			_print_failure("runner::engine", unassociated)
			failed += 1
		var script: GDScript = load("res://tests/" + filename) as GDScript
		var load_errors: PackedStringArray = _error_logger.take_errors()
		if script == null or not script.can_instantiate() or not load_errors.is_empty():
			if load_errors.is_empty():
				load_errors.append("script could not be loaded or instantiated")
			_print_failure(filename + "::load", load_errors)
			failed += 1
			continue
		var instance: Object = script.new()
		var instance_errors: PackedStringArray = _error_logger.take_errors()
		if instance == null or not instance_errors.is_empty():
			if instance_errors.is_empty():
				instance_errors.append("script instance could not be created")
			_print_failure(filename + "::instantiate", instance_errors)
			failed += 1
			if instance is Node:
				instance.free()
			continue
		if not instance is TestCase:
			if instance is Node:
				instance.free()
			continue
		var test_case: TestCase = instance as TestCase
		var methods: Array[String] = []
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = String(method["name"])
			if method_name.begins_with("test_") and not methods.has(method_name):
				methods.append(method_name)
		methods.sort()
		for method_name: String in methods:
			matched += 1
			test_case.before_each()
			test_case.call(method_name)
			var failures: PackedStringArray = test_case.take_failures()
			failures.append_array(_error_logger.take_errors())
			if failures.is_empty():
				passed += 1
				print("PASS %s::%s" % [filename, method_name])
			else:
				failed += 1
				_print_failure("%s::%s" % [filename, method_name], failures)
	OS.remove_logger(_error_logger)
	var remaining_errors: PackedStringArray = _error_logger.take_errors()
	if not remaining_errors.is_empty():
		_print_failure("runner::engine", remaining_errors)
		failed += 1
	if matched == 0:
		print("FAIL runner::selection: no test methods matched filter '%s'" % filter)
		failed += 1
	print("%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
