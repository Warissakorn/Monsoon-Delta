extends "res://tools/end_turn_probe.gd"
## Real turn input; only the presentation clock is frozen for screenshots.


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			language = arg.trim_prefix("--lang=")
		elif arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	if DisplayServer.get_name() == "headless" or language not in ["en", "th"] or not out_dir.is_absolute_path():
		printerr("Use a native display, --lang=en|th and an absolute --out-dir.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	path = out_dir.path_join("checkpoint.json")
	settings = out_dir.path_join("settings.json")
	Localization.setup(language)
	root.size = Vector2i(1280, 720)
	_check("isolated_preferences", GamePreferences.write({"language": language, "confirm_unused_labor": false, "reduced_motion": false}, settings).is_empty())

	var initial: GameState = Fixtures.create()
	initial.labor = 2
	var reference: GameState = initial.duplicate_state()
	GameFlow.end_turn(reference)
	var before: Dictionary = ResourceFeedback.capture(initial)
	_case(initial)
	await _frames(3)
	await _burst(screen._end_button)
	var effect: ResourceFeedback = screen._resource_feedback
	effect.set_process(false)
	_check("native_burst_commits_one_turn_and_one_effect", screen.session.state.to_dict() == reference.to_dict() and screen.session.turn_history().size() == 1 and effect.generation == 1)
	_check("gains_use_actual_before_after", effect.last_changes == ResourceFeedback.difference(before, ResourceFeedback.capture(screen.session.state)))
	_check("food_and_labor_gain_visible", effect.last_changes.get("food", {}).get("delta") == 1 and effect.last_changes.get("labor", {}).get("delta") == 4)
	_check("unchanged_wood_and_housing_have_no_badges", not effect.last_changes.has("wood") and not effect.last_changes.has("housing"))
	_check("normal_animation_was_observed", not effect._entries.is_empty() and float(effect._entries[0]["age"]) > 0.0 and (effect._entries[0]["badge"] as Control).position != Vector2(effect._entries[0]["base"]))
	_check_badges("gains")
	await _capture("resource-gains")
	var committed: Dictionary = screen.session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	await _click(screen.hud.find_child("Pause", true, false) as Button)
	_check("effect_layer_does_not_block_mouse_input", screen.modal_kind == "pause")
	_check("pause_clears_effect_without_state_or_save_change", effect._entries.is_empty() and screen.session.state.to_dict() == committed and FileAccess.get_file_as_bytes(path) == bytes)
	await _click(screen._modal.find_child("Resume", true, false) as Button)
	_check("resume_does_not_replay_effect", effect._entries.is_empty())

	initial = Fixtures.create(true, 6)
	initial.food = 2
	initial.labor = 1
	reference = initial.duplicate_state()
	GameFlow.end_turn(reference)
	before = ResourceFeedback.capture(initial)
	_case(initial)
	await _frames(3)
	await _click(screen._end_button)
	await _burst(screen._modal.find_child("ConfirmEndTurn", true, false) as Button)
	effect = screen._resource_feedback
	effect.set_process(false)
	_check("harvest_commit_matches_reference", screen.modal_kind == "harvest" and screen.session.state.to_dict() == reference.to_dict())
	_check("harvest_shows_actual_net_losses", effect.last_changes == ResourceFeedback.difference(before, ResourceFeedback.capture(screen.session.state)))
	_check("population_and_housing_loss_are_distinct", effect.last_changes.get("people", {}).get("delta") == -3 and effect.last_changes.get("housing", {}).get("delta") == -2)
	_check("loss_effect_is_above_harvest_overlay", not effect._entries.is_empty() and effect.z_index > screen._modal.z_index)
	_check_badges("losses")
	await _capture("resource-harvest-losses")
	committed = screen.session.state.to_dict()
	bytes = FileAccess.get_file_as_bytes(path)
	effect.set_process(true)
	await create_timer(ResourceFeedback.LIFETIME + 0.15).timeout
	await _frames(2)
	_check("real_time_expiry_frees_all_effects", effect._entries.is_empty() and effect.get_child_count() == 0 and not effect.is_processing())
	_check("animation_and_expiry_preserve_rng_history_and_save", screen.session.state.to_dict() == committed and screen.session.turn_history().size() == 1 and FileAccess.get_file_as_bytes(path) == bytes)
	await _key(KEY_H)
	await _key(KEY_ESCAPE)
	_check("return_to_harvest_does_not_replay", screen.modal_kind == "harvest" and effect._entries.is_empty())
	before = ResourceFeedback.capture(screen.session.state)
	reference = screen.session.state.duplicate_state()
	GameFlow.continue_after_harvest(reference)
	await _click(screen._modal.find_child("ContinueHarvest", true, false) as Button)
	effect.set_process(false)
	_check("new_year_effect_uses_only_new_year_delta", screen.session.state.to_dict() == reference.to_dict() and effect.last_changes == ResourceFeedback.difference(before, ResourceFeedback.capture(screen.session.state)))
	_check("year_transition_did_not_end_first_turn", screen.session.state.year == 2 and screen.session.state.turn == 1 and screen.session.turn_history().size() == 1)

	initial = Fixtures.create()
	initial.labor = 2
	_case(initial)
	await _frames(3)
	await _click(screen.hud.find_child("Pause", true, false) as Button)
	await _click(screen._modal.find_child("ReducedMotion", true, false) as CheckBox)
	await _click(screen._modal.find_child("Resume", true, false) as Button)
	await _click(screen._end_button)
	effect = screen._resource_feedback
	effect.set_process(false)
	_check("native_reduced_motion_preference", screen.reduced_motion and effect._reduced_motion)
	var positions: Array[Vector2] = []
	for entry: Dictionary in effect._entries:
		positions.append((entry["badge"] as Control).position)
		_check("reduced_no_tokens_%s" % String(entry["key"]), entry["tokens"].is_empty() and (entry["badge"] as Control).scale == Vector2.ONE and (entry["badge"] as Control).modulate.a == 1.0)
	effect.set_process(true)
	await create_timer(0.3).timeout
	effect.set_process(false)
	for index: int in range(effect._entries.size()):
		_check("reduced_stays_static_%d" % index, (effect._entries[index]["badge"] as Control).position == positions[index])
	_check_badges("reduced")
	await _capture("resource-reduced-motion")
	var loaded: GameSession = GameSession.new()
	loaded.save_path = path
	_check("load_exact_checkpoint", loaded.load_game().is_empty() and loaded.state.to_dict() == screen.session.state.to_dict())
	_show(loaded)
	await _frames(2)
	_check("loading_does_not_replay_old_effects", screen._resource_feedback._entries.is_empty() and screen._resource_feedback.generation == 0)

	initial = Fixtures.create()
	initial.get_tile(Vector2i(1, 0)).building = C.Building.NONE
	_case(initial)
	await _frames(2)
	await _click(screen._end_button)
	_check("rice_yield_without_food_does_not_flash_food", screen.session.state.get_tile(Fixtures.FIELD).paddy_yield == 1 and screen._resource_feedback._entries.is_empty() and screen._resource_feedback.generation == 0)

	_school_case()
	await _frames(3)
	before = ResourceFeedback.capture(screen.session.state)
	await _click(screen._end_button)
	effect = screen._resource_feedback
	effect.set_process(false)
	_check("school_result_uses_actual_delta", screen.modal_kind == "school_result" and effect.last_changes == ResourceFeedback.difference(before, ResourceFeedback.capture(screen.session.state)))
	_check("school_effect_visible_over_result", not effect._entries.is_empty() and effect.z_index > screen._modal.z_index)
	await _wait_for_input()
	await _click(screen._modal.find_child("SchoolRetry", true, false) as Button)
	_check("school_retry_clears_effects", screen._resource_feedback._entries.is_empty() and screen._resource_feedback.last_changes.is_empty() and screen.session.turn_history().is_empty())

	var output: Dictionary = {
		"engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(), "language": language,
		"viewport": [1280, 720], "checks": checks, "captures": captures,
		"lifetime_seconds": ResourceFeedback.LIFETIME, "max_tokens": ResourceFeedback.MAX_TOKENS,
		"fixture_sha256": FileAccess.get_sha256("res://tools/end_turn_fixtures.gd"),
		"probe_sha256": FileAccess.get_sha256("res://tools/resource_feedback_probe.gd"),
		"balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"note": "Automated native mouse/keyboard at 1280x720. Authored initial safe, harvest-loss, no-resource-change and school UI boards use isolated checkpoint/settings paths. State is installed before each case starts; all following turns use real input and unchanged gameplay rules. Only the effect's presentation clock is frozen after observed motion to take screenshots, then resumed to check real-time expiry and static reduced-motion behavior. School input guard expiry is awaited. Screenshots label authored fixtures. This is not a generated-map playthrough, human playtest, balance validation or performance benchmark.",
	}
	var file: FileAccess = FileAccess.open(out_dir.path_join("resource-feedback-qa-" + language + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  ", true, true))
	file.close()
	print("RESOURCE_FEEDBACK_QA ", language, " ", checks.size(), " checks; failed=", failed)
	quit(1 if failed else 0)


func _check_badges(prefix: String) -> void:
	var effect: ResourceFeedback = screen._resource_feedback
	var tokens: int = 0
	for entry: Dictionary in effect._entries:
		var badge: Control = entry["badge"]
		_check(prefix + "_badge_fits_" + String(entry["key"]), root.get_visible_rect().encloses(badge.get_global_rect()))
		var label: Label = screen._resource_chips[entry["target"]]
		var font: Font = label.get_theme_font("font")
		var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		var counter: Rect2 = Rect2(label.global_position, Vector2(width, label.size.y))
		_check(prefix + "_counter_not_covered_" + String(entry["key"]), not badge.get_global_rect().intersects(counter))
		var sign_label: Label = badge.find_child("SignedDelta", true, false) as Label
		_check(prefix + "_actual_signed_delta_" + String(entry["key"]), sign_label.text == "%+d" % int(effect.last_changes[entry["key"]]["delta"]))
		tokens += entry["tokens"].size()
	_check(prefix + "_bounded_particle_count", tokens <= ResourceFeedback.MAX_TOKENS)


func _school_case() -> void:
	if is_instance_valid(screen):
		root.remove_child(screen)
		screen.queue_free()
	var lesson: RiverSchoolRun = RiverSchoolRun.new()
	_check("school_fixture_start", lesson.start("river_school_01"))
	lesson.session.state = Fixtures.create(false, 6)
	lesson.session.state.is_tutorial = true
	var school: RiverSchoolScreen = RiverSchoolScreen.new()
	school.lesson = lesson
	school.session = lesson.session
	school.preferences_path = settings
	screen = school
	root.add_child(screen)
	screen.confirm_unused_labor = false


func _check(name: String, ok: bool) -> void:
	checks[name] = ok
	if not ok:
		failed = true
		printerr("RESOURCE FEEDBACK CHECK FAILED: ", name)
