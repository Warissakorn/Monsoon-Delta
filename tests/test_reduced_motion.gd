extends TestCase
## Presentation preferences stop motion without changing simulation or targets.

const SandboxScreen = preload("res://ui/sandbox_screen.gd")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_weather_toggle_stops_existing_rain_and_snaps_to_the_current_season() -> void:
	var atmosphere := DeltaAtmosphere.new()
	_root().add_child(atmosphere)
	atmosphere.set_rain(false)
	atmosphere.set_rain(true)
	var transition: Tween = atmosphere._weather_tween
	assert_true(transition != null and transition.is_valid())
	transition.custom_step(0.4)
	assert_true(atmosphere._weather_weight > 0.0 and atmosphere._weather_weight < 1.0)
	assert_true(atmosphere._rain.emitting)
	atmosphere.set_reduced_motion(true)
	assert_true(not transition.is_valid(), "an in-flight weather transition cannot keep moving")
	assert_true(atmosphere._weather_tween == null)
	assert_true(not atmosphere._rain.emitting)
	assert_true(not atmosphere._rain.visible, "already emitted drops disappear immediately")
	assert_true(atmosphere._rainy, "reducing motion does not change the chosen season")
	assert_near(atmosphere._weather_weight, 1.0, 0.00001)
	assert_near(atmosphere._sun.light_energy, 0.44, 0.00001)
	atmosphere.set_rain(false)
	assert_near(atmosphere._weather_weight, 0.0, 0.00001, "future season changes are immediate")
	assert_near(atmosphere._sun.light_energy, 0.58, 0.00001)
	assert_true(atmosphere._weather_tween == null)
	atmosphere.set_rain(true)
	atmosphere.set_reduced_motion(false)
	assert_true(atmosphere._rain.visible and atmosphere._rain.emitting, "normal rain resumes for the retained rainy season")
	atmosphere.set_rain(false)
	assert_true(atmosphere._weather_tween != null and atmosphere._weather_tween.is_valid(), "normal weather transitions resume")
	atmosphere.free()


func test_camera_toggle_finishes_active_targets_and_future_steps_are_immediate() -> void:
	var rig := CameraRig.new()
	_root().add_child(rig)
	rig.rotate_step(1)
	rig.zoom_step(-1)
	var orbit: Tween = rig._orbit_tween
	var zoom: Tween = rig._zoom_tween
	orbit.custom_step(0.05)
	zoom.custom_step(0.05)
	assert_true(absf(rig.rotation.y - rig._yaw_target) > 0.00001)
	assert_true(absf(rig.camera.size - rig._zoom_target) > 0.00001)
	var expected_yaw: float = rig._yaw_target
	var expected_zoom: float = rig._zoom_target
	rig.set_reduced_motion(true)
	assert_true(not orbit.is_valid() and not zoom.is_valid())
	assert_true(rig._orbit_tween == null and rig._zoom_tween == null)
	assert_near(rig.rotation.y, expected_yaw, 0.00001)
	assert_near(rig.camera.size, expected_zoom, 0.00001)
	rig.rotate_step(-1)
	rig.zoom_step(1)
	assert_near(rig.rotation.y, expected_yaw - deg_to_rad(60.0), 0.00001)
	assert_near(rig.camera.size, expected_zoom + 1.5, 0.00001)
	assert_true(rig._orbit_tween == null and rig._zoom_tween == null)
	rig.zoom_step(100)
	assert_near(rig.camera.size, 27.0, 0.00001, "instant zoom retains the existing bounds")
	rig.set_reduced_motion(false)
	rig.rotate_step(1)
	rig.zoom_step(-1)
	assert_true(rig._orbit_tween != null and rig._orbit_tween.is_valid())
	assert_true(rig._zoom_tween != null and rig._zoom_tween.is_valid())
	rig.free()


func test_water_updates_cached_and_future_materials_without_changing_state_or_other_views() -> void:
	var state: GameState = TestMaps.small(1, 1)
	state.get_tile(Vector2i.ZERO).water = 0.3
	var before: Dictionary = state.to_dict()
	var rng: int = state.rng.state
	var board := BoardView.new()
	board.set_reduced_motion(true)
	board.set_state(state)
	assert_eq(board._water_materials.size(), 1)
	var first: ShaderMaterial = board._water_materials.values()[0]
	assert_near(float(first.get_shader_parameter("motion_scale")), 0.0, 0.00001)
	var other := BoardView.new()
	other.set_state(state)
	var independent: ShaderMaterial = other._water_materials.values()[0]
	assert_near(float(independent.get_shader_parameter("motion_scale")), 1.0, 0.00001)
	board.set_reduced_motion(false)
	assert_near(float(first.get_shader_parameter("motion_scale")), 1.0, 0.00001, "existing rendered water resumes")
	assert_eq(state.to_dict(), before)
	state.get_tile(Vector2i.ZERO).water = 2.2
	before = state.to_dict()
	board.refresh()
	assert_eq(board._water_materials.size(), 1, "changing depth reuses the coordinate material")
	for material: ShaderMaterial in board._water_materials.values():
		assert_near(float(material.get_shader_parameter("motion_scale")), 1.0, 0.00001)
	assert_eq(state.to_dict(), before)
	board.set_reduced_motion(true)
	state.get_tile(Vector2i(1, 0)).water = 3.5
	before = state.to_dict()
	board.set_state(state.duplicate_state())
	assert_eq(board._water_materials.size(), 2, "only wet coordinates keep current materials")
	for material: ShaderMaterial in board._water_materials.values():
		assert_near(float(material.get_shader_parameter("motion_scale")), 0.0, 0.00001, "new wet tile materials inherit the current preference")
	assert_near(float(independent.get_shader_parameter("motion_scale")), 1.0, 0.00001, "shared shader resources do not share the motion setting")
	assert_eq(state.to_dict(), before)
	assert_eq(board.state.to_dict(), before)
	assert_eq(state.rng.state, rng)
	board.free()
	other.free()


func test_apis_accept_startup_preferences_before_entering_the_tree() -> void:
	var atmosphere := DeltaAtmosphere.new()
	atmosphere.set_reduced_motion(true)
	atmosphere.set_rain(true)
	assert_true(not atmosphere._rain.visible and not atmosphere._rain.emitting)
	assert_near(atmosphere._weather_weight, 1.0, 0.00001)
	var rig := CameraRig.new()
	rig.set_reduced_motion(true)
	rig.rotate_step(1)
	rig.zoom_step(-1)
	assert_near(rig.rotation.y, rig._yaw_target, 0.00001)
	assert_near(rig.camera.size, rig._zoom_target, 0.00001)
	atmosphere.free()
	rig.free()
	var expected: bool = bool(GamePreferences.read().get("reduced_motion", false))
	var sandbox := SandboxScreen.new()
	sandbox._build_world()
	var world: DeltaAtmosphere = sandbox.get_child(0) as DeltaAtmosphere
	assert_eq(world._reduced_motion, expected)
	assert_eq(sandbox.board._reduced_motion, expected)
	assert_eq(sandbox.camera_rig._reduced_motion, expected)
	sandbox.free()
