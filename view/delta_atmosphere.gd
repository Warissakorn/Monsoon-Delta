class_name DeltaAtmosphere
extends Node3D
## Purely visual seasonal light, lagoon backdrop and light rain.

var _sun: DirectionalLight3D
var _environment: Environment
var _floor_material: ShaderMaterial
var _rain: CPUParticles3D
var _weather_tween: Tween
var _rainy: bool = false
var _initialized: bool = false
var _weather_set: bool = false
var _weather_weight: float = 0.0
var _reduced_motion: bool = false


func _ready() -> void:
	_setup()


func _setup() -> void:
	if _initialized:
		return
	_initialized = true
	var colors: Dictionary = ThemeBuilder.palette()
	var world := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(colors.background)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("b8cecc")
	_environment.ambient_light_energy = 0.28
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = _environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.name = "AfternoonSun"
	_sun.rotation_degrees = Vector3(-48, -32, 0)
	_sun.light_color = Color("fff0da")
	_sun.light_energy = 0.58
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 45.0
	_sun.shadow_bias = 0.035
	add_child(_sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 145, 0)
	fill.light_color = Color("9bc7cf")
	fill.light_energy = 0.12
	add_child(fill)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(160, 160)
	var floor_view := MeshInstance3D.new()
	floor_view.name = "LagoonBackdrop"
	floor_view.mesh = floor_mesh
	floor_view.position.y = BoardView.BASE_Y - 0.04
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = preload("res://view/lagoon_floor.gdshader")
	_floor_material.set_shader_parameter("outer_color", Color(colors.background))
	floor_view.material_override = _floor_material
	add_child(floor_view)
	_rain = CPUParticles3D.new()
	_rain.name = "SeasonalRain"
	_rain.position.y = 9.0
	_rain.amount = 180
	_rain.lifetime = 1.4
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(7.0, 0.5, 7.0)
	_rain.direction = Vector3(-0.15, -1.0, 0.1)
	_rain.spread = 3.0
	_rain.gravity = Vector3(0, -7.0, 0)
	_rain.initial_velocity_min = 4.0
	_rain.initial_velocity_max = 5.0
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.28, 0.012)
	var drop_material := StandardMaterial3D.new()
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.albedo_color = Color(0.72, 0.87, 0.91, 0.2)
	drop.material = drop_material
	_rain.mesh = drop
	_rain.emitting = false
	add_child(_rain)


func set_rain(rainy: bool) -> void:
	_setup()
	if _weather_set and _rainy == rainy:
		return
	_rainy = rainy
	if _weather_tween != null and _weather_tween.is_valid():
		_weather_tween.kill()
	_rain.emitting = rainy and not _reduced_motion
	if not _weather_set or _reduced_motion:
		_blend_weather(1.0 if rainy else 0.0)
	else:
		_weather_tween = create_tween()
		_weather_tween.tween_method(_blend_weather, _weather_weight, 1.0 if rainy else 0.0, 1.4)
	_weather_set = true


func set_reduced_motion(enabled: bool) -> void:
	_setup()
	_reduced_motion = enabled
	# Hiding also removes particles already in flight, without changing season.
	_rain.visible = not enabled
	_rain.emitting = _rainy and not enabled
	if enabled:
		if _weather_tween != null and _weather_tween.is_valid():
			_weather_tween.kill()
		_weather_tween = null
		_blend_weather(1.0 if _rainy else 0.0)


func _blend_weather(weight: float) -> void:
	_weather_weight = weight
	_sun.light_color = Color("fff0da").lerp(Color("c1d5df"), weight)
	_sun.light_energy = lerpf(0.58, 0.44, weight)
	_environment.ambient_light_color = Color("b8cecc").lerp(Color("a5c0cc"), weight)
	_floor_material.set_shader_parameter("rain_blend", weight)
