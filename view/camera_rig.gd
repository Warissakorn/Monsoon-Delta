class_name CameraRig
extends Node3D

## An orthographic orbit keeps the board legible while inspecting water levels.
var camera: Camera3D
var _pitch: Node3D
var _yaw_target: float = deg_to_rad(-12.0)
var _zoom_target: float = 19.5
var _orbit_tween: Tween
var _zoom_tween: Tween
var _initialized: bool = false


func _ready() -> void:
	setup()


func setup() -> void:
	if _initialized:
		return
	_initialized = true
	position = Vector3(0.0, 0.3, 0.0)
	rotation.y = _yaw_target
	_pitch = Node3D.new()
	_pitch.name = "Pitch"
	_pitch.rotation_degrees.x = -49.0
	add_child(_pitch)
	camera = Camera3D.new()
	camera.name = "OverviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom_target
	camera.near = 0.1
	camera.far = 100.0
	camera.position = Vector3(0.0, 0.0, 24.0)
	camera.current = true
	_pitch.add_child(camera)


func get_camera() -> Camera3D:
	setup()
	return camera


func rotate_step(direction: int) -> void:
	setup()
	_yaw_target += deg_to_rad(60.0) * float(direction)
	if _orbit_tween != null and _orbit_tween.is_valid():
		_orbit_tween.kill()
	_orbit_tween = create_tween()
	_orbit_tween.tween_property(self, "rotation:y", _yaw_target, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func zoom_step(direction: int) -> void:
	setup()
	_zoom_target = clampf(_zoom_target + float(direction) * 1.5, 12.0, 27.0)
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(camera, "size", _zoom_target, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func pan(vector: Vector2, delta: float) -> void:
	setup()
	var forward: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	var right: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, rotation.y)
	var movement: Vector3 = (right * vector.x - forward * vector.y) * delta * 8.0
	position.x = clampf(position.x + movement.x, -5.0, 5.0)
	position.z = clampf(position.z + movement.z, -5.0, 5.0)
