extends TestCase
const F = preload("res://tools/end_turn_fixtures.gd")
const DIRECTORY: String = "user://tests/resource_feedback"
const PATH: String = DIRECTORY + "/checkpoint.json"
const SETTINGS: String = DIRECTORY + "/settings.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	Localization.setup("en")


func _screen(state: GameState = null) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = GameSession.new()
	screen.session.state = F.create() if state == null else state
	screen.session.save_path = PATH
	screen.preferences_path = SETTINGS
	assert_eq(screen.session.checkpoint(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = false
	return screen


func _widget() -> ResourceFeedback:
	var parent: Control = Control.new()
	parent.theme = ThemeBuilder.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(parent)
	var chips: Dictionary = {}
	for index: int in range(4):
		var chip: Control = Control.new()
		chip.position = Vector2(20 + index * 280, 60)
		chip.size = Vector2(260, 32)
		parent.add_child(chip)
		var label: Label = Label.new()
		label.text = "Resource 10"
		chip.add_child(label)
		chips[["labor", "food", "wood", "people"][index]] = label
	var feedback: ResourceFeedback = ResourceFeedback.new()
	parent.add_child(feedback)
	feedback.bind_chips(chips)
	return feedback


func _before() -> Dictionary:
	return {"labor": 2, "food": 10, "wood": 5, "people": 6, "housing": 6}


func _after() -> Dictionary:
	return {"labor": 6, "food": 8, "wood": 8, "people": 5, "housing": 4}


func _entry(feedback: ResourceFeedback, key: String) -> Dictionary:
	for entry: Dictionary in feedback._entries:
		if entry["key"] == key:
			return entry
	return {}


func _assert_passive(node: Node) -> void:
	if node is Control:
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq((node as Control).focus_mode, Control.FOCUS_NONE)
	for child: Node in node.get_children():
		_assert_passive(child)


func test_difference_uses_signed_actual_values_and_keeps_housing_distinct_from_people() -> void:
	var changes: Dictionary = ResourceFeedback.difference(_before(), _after())
	assert_eq(changes["labor"], {"before": 2, "after": 6, "delta": 4})
	assert_eq(changes["food"]["delta"], -2)
	assert_eq(changes["wood"]["delta"], 3)
	assert_eq(changes["people"]["delta"], -1)
	assert_eq(changes["housing"]["delta"], -2)
	assert_true(ResourceFeedback.difference(_before(), _before()).is_empty())


func test_badges_have_signs_colors_and_a_bounded_noninteractive_particle_count() -> void:
	var feedback: ResourceFeedback = _widget()
	feedback.show_changes(_before(), _after())
	assert_eq(feedback._entries.size(), 5)
	var tokens: int = 0
	for entry: Dictionary in feedback._entries:
		tokens += entry["tokens"].size()
		var label: Label = (entry["badge"] as Control).find_child("SignedDelta", true, false) as Label
		var delta: int = int(feedback.last_changes[entry["key"]]["delta"])
		assert_eq(label.text, "%+d" % delta)
		assert_eq(label.get_theme_color("font_color"), Color(ThemeBuilder.palette()["success" if delta > 0 else "danger"]))
	assert_eq(tokens, ResourceFeedback.MAX_TOKENS)
	assert_eq(feedback.z_index, 80)
	_assert_passive(feedback)
	feedback.get_parent().free()


func test_replacing_and_expiring_effects_frees_the_old_visuals_and_stops_processing() -> void:
	var feedback: ResourceFeedback = _widget()
	feedback.show_changes(_before(), _after())
	var old: WeakRef = weakref(feedback._entries[0]["root"])
	feedback.show_changes(_after(), _before())
	assert_eq(old.get_ref(), null)
	assert_eq(feedback.get_child_count(), 5)
	assert_eq(feedback.generation, 2)
	feedback._process(ResourceFeedback.LIFETIME + 0.1)
	assert_eq(feedback.get_child_count(), 0)
	assert_true(feedback.last_changes.is_empty())
	assert_true(not feedback.is_processing())
	feedback.show_changes(_before(), _before())
	assert_eq(feedback.get_child_count(), 0)
	assert_eq(feedback.generation, 2, "unchanged totals produce no +0 effect")
	feedback.get_parent().free()


func test_normal_motion_moves_tokens_and_badges_without_accepting_invalid_frame_times() -> void:
	var feedback: ResourceFeedback = _widget()
	feedback.show_changes(_before(), _after())
	var gain: Dictionary = _entry(feedback, "wood")
	var loss: Dictionary = _entry(feedback, "food")
	var gain_at: Vector2 = (gain["tokens"][0] as Control).position
	var loss_at: Vector2 = (loss["tokens"][0] as Control).position
	feedback._process(0.2)
	assert_true((gain["tokens"][0] as Control).position != gain_at)
	assert_true((loss["tokens"][0] as Control).position != loss_at)
	assert_true((gain["badge"] as Control).position != Vector2(gain["base"]))
	for delta: float in [0.0, -1.0, NAN, INF]:
		feedback._process(delta)
	assert_near(float(gain["age"]), 0.2, 0.00001)
	feedback._process(0.6)
	assert_true(gain["tokens"].is_empty())
	feedback.get_parent().free()


func test_reduced_motion_is_static_removes_active_tokens_and_applies_to_future_effects() -> void:
	var feedback: ResourceFeedback = _widget()
	feedback.show_changes(_before(), _after())
	var entry: Dictionary = feedback._entries[0]
	var token: WeakRef = weakref(entry["tokens"][0])
	feedback._process(0.2)
	feedback.set_reduced_motion(true)
	assert_eq(token.get_ref(), null)
	var badge: Control = entry["badge"]
	var position: Vector2 = badge.position
	feedback._process(0.6)
	assert_eq(badge.position, position)
	assert_eq(badge.scale, Vector2.ONE)
	assert_eq(badge.modulate.a, 1.0)
	feedback.show_changes(_before(), _after())
	for next: Dictionary in feedback._entries:
		assert_true(next["tokens"].is_empty())
	feedback.set_reduced_motion(false)
	feedback.show_changes(_before(), _after())
	assert_eq(feedback._entries[0]["tokens"].size(), 3)
	feedback.get_parent().free()


func test_hud_placement_follows_its_resource_chip_and_shares_people_space_without_overlap() -> void:
	var feedback: ResourceFeedback = _widget()
	feedback.set_reduced_motion(true)
	feedback.show_changes(_before(), _after())
	var people: Control = _entry(feedback, "people")["badge"]
	var housing: Control = _entry(feedback, "housing")["badge"]
	assert_true(not people.get_global_rect().intersects(housing.get_global_rect()))
	var food: Dictionary = _entry(feedback, "food")
	var previous: Vector2 = (food["root"] as Control).position
	var target: Control = (feedback._chips["food"] as Label).get_parent() as Control
	target.position += Vector2(30, 10)
	feedback._process(0.1)
	assert_eq((food["root"] as Control).position, previous + Vector2(30, 10))
	feedback.get_parent().free()


func test_committed_turn_shows_food_and_labor_changes_without_inventing_wood_or_rice_food() -> void:
	var state: GameState = F.create()
	state.labor = 2
	var screen: GameScreen = _screen(state)
	var before: Dictionary = ResourceFeedback.capture(state)
	screen._finish_turn()
	var changes: Dictionary = screen._resource_feedback.last_changes
	assert_eq(changes, ResourceFeedback.difference(before, ResourceFeedback.capture(state)))
	assert_eq(changes["food"]["delta"], 1)
	assert_eq(changes["labor"]["delta"], 4)
	assert_true(not changes.has("wood"))
	assert_true(not changes.has("housing"))
	assert_eq(screen._resource_chips["food"].text, _tr("resource.food") + " 51", "the total is already final while its effect animates")
	assert_eq(state.get_tile(F.FIELD).paddy_yield, 1)
	screen.free()


func test_harvest_losses_show_actual_net_food_population_and_capacity_above_the_summary() -> void:
	var state: GameState = F.create(true, 6)
	state.food = 2
	var screen: GameScreen = _screen(state)
	var before: Dictionary = ResourceFeedback.capture(state)
	screen._finish_turn()
	assert_eq(screen.modal_kind, "harvest")
	var changes: Dictionary = screen._resource_feedback.last_changes
	assert_eq(changes, ResourceFeedback.difference(before, ResourceFeedback.capture(state)))
	assert_eq(changes["food"]["delta"], -2)
	assert_eq(changes["people"]["delta"], -3)
	assert_eq(changes["housing"]["delta"], -2)
	assert_true(screen._resource_feedback.z_index > screen._modal.z_index)
	screen.free()


func test_births_can_gain_population_while_the_same_harvest_reduces_food() -> void:
	var state: GameState = F.create(false, 6)
	state.get_tile(Vector2i(0, 1)).building = C.Building.HOUSE
	var screen: GameScreen = _screen(state)
	screen._finish_turn()
	assert_true(int(screen._resource_feedback.last_changes["people"]["delta"]) > 0)
	assert_true(int(screen._resource_feedback.last_changes["food"]["delta"]) < 0)
	assert_true(not screen._resource_feedback.last_changes.has("housing"))
	screen.free()


func test_unchanged_counters_show_no_effect_even_when_rice_yield_increases() -> void:
	var state: GameState = F.create()
	state.get_tile(Vector2i(1, 0)).building = C.Building.NONE
	var screen: GameScreen = _screen(state)
	screen._finish_turn()
	assert_eq(state.get_tile(F.FIELD).paddy_yield, 1)
	assert_true(screen._resource_feedback._entries.is_empty())
	assert_true(screen._resource_feedback.last_changes.is_empty())
	assert_eq(screen._resource_feedback.generation, 0)
	screen.free()


func test_cancelled_turn_and_repeated_input_never_generate_a_second_resource_event() -> void:
	var screen: GameScreen = _screen(F.create(true))
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_impact")
	assert_eq(screen._resource_feedback.generation, 0)
	screen.close_modal()
	assert_eq(screen._resource_feedback.generation, 0)
	screen.request_end_turn()
	screen._confirm_end_turn()
	var committed: Dictionary = screen.session.state.to_dict()
	screen._end_input_locked_until = Time.get_ticks_msec() + 60000
	for _repeat: int in range(3):
		screen.request_end_turn_from_input()
	assert_eq(screen.session.state.to_dict(), committed)
	assert_eq(screen._resource_feedback.generation, 1)
	screen.free()


func test_expiry_and_motion_changes_do_not_touch_rng_history_stacks_or_checkpoint() -> void:
	var screen: GameScreen = _screen()
	screen._finish_turn()
	var before: Dictionary = screen.session.state.to_dict()
	var history: Array[Dictionary] = screen.session.turn_history()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen._on_motion_toggled(true)
	assert_true(screen._resource_feedback._reduced_motion)
	screen._resource_feedback._process(ResourceFeedback.LIFETIME + 0.1)
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.session.turn_history(), history)
	assert_true(screen.session.state.undo.is_empty())
	assert_true(screen.session.state.redo.is_empty())
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen.free()


func test_history_commands_undo_and_load_do_not_replay_old_resource_changes() -> void:
	var screen: GameScreen = _screen()
	screen._finish_turn()
	screen.open_turn_history()
	assert_true(screen._resource_feedback._entries.is_empty())
	screen.close_turn_history()
	assert_true(screen._resource_feedback._entries.is_empty())
	screen.select_command("fill")
	screen.apply_at(Vector2i.ZERO)
	screen.undo_command()
	assert_eq(screen._resource_feedback.generation, 1)
	var restored: GameSession = GameSession.new()
	restored.save_path = PATH
	assert_eq(restored.load_game(), "")
	screen.free()
	screen = GameScreen.new()
	screen.session = restored
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	assert_true(screen._resource_feedback._entries.is_empty())
	assert_eq(screen._resource_feedback.generation, 0)
	screen.free()


func test_continuing_year_shows_only_new_year_changes_once() -> void:
	var state: GameState = F.create(false, 6)
	state.labor = 1
	var screen: GameScreen = _screen(state)
	screen._finish_turn()
	var before: Dictionary = ResourceFeedback.capture(state)
	screen.continue_harvest()
	assert_eq(state.year, 2)
	assert_eq(state.turn, 1)
	var expected: Dictionary = ResourceFeedback.difference(before, ResourceFeedback.capture(state))
	assert_eq(screen._resource_feedback.last_changes, expected)
	var generation: int = screen._resource_feedback.generation
	screen.continue_harvest()
	assert_eq(screen._resource_feedback.generation, generation)
	screen.free()


func test_school_uses_the_same_committed_effect_and_retry_clears_it() -> void:
	var lesson: RiverSchoolRun = RiverSchoolRun.new()
	assert_true(lesson.start("river_school_01"))
	lesson.session.state = F.create(false, 6)
	lesson.session.state.is_tutorial = true
	var screen: RiverSchoolScreen = RiverSchoolScreen.new()
	screen.lesson = lesson
	screen.session = lesson.session
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	var before: Dictionary = ResourceFeedback.capture(screen.session.state)
	screen._finish_turn()
	assert_eq(screen.modal_kind, "school_result")
	assert_eq(screen._resource_feedback.last_changes, ResourceFeedback.difference(before, ResourceFeedback.capture(screen.session.state)))
	assert_true(not screen._resource_feedback._entries.is_empty())
	screen.retry_lesson()
	assert_true(screen._resource_feedback._entries.is_empty())
	assert_true(screen._resource_feedback.last_changes.is_empty())
	screen.free()


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))
