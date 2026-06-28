extends CharacterBody3D

## 3D player controller for tycoon-style games.
## Third-person camera with WASD movement and mouse look.

@export var move_speed: float = 8.0
@export var sprint_speed: float = 14.0
@export var camera_sensitivity: float = 0.003
@export var camera_distance: float = 12.0
@export var camera_height: float = 8.0
@export var camera_pitch: float = -45.0

var gravity: float = -20.0
var is_sprinting: bool = false
var camera_rotation_yaw: float = 0.0
var camera_rotation_pitch: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_camera()


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation_yaw -= event.relative.x * camera_sensitivity
		camera_rotation_pitch -= event.relative.y * camera_sensitivity
		camera_rotation_pitch = clampf(camera_rotation_pitch, -80.0, -10.0)

	# Escape to free mouse
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Click to recapture
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	is_sprinting = Input.is_action_pressed("sprint")

	var input_dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)

	# Transform input relative to camera yaw
	var forward: Vector3 = -Vector3.FORWARD.rotated(Vector3.UP, camera_rotation_yaw)
	var right: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, camera_rotation_yaw)

	var move_dir: Vector3 = (right * input_dir.x + forward * input_dir.y).normalized()
	var speed: float = sprint_speed if is_sprinting else move_speed

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	_update_camera()


func _setup_camera() -> void:
	camera_pivot.position = Vector3(0, camera_height, 0)
	camera.position = Vector3(0, 0, camera_distance)


func _update_camera() -> void:
	camera_pivot.global_position = global_position + Vector3(0, camera_height, 0)
	camera_pivot.rotation.y = camera_rotation_yaw
	camera.rotation.x = deg_to_rad(camera_rotation_pitch)
	camera.look_at(camera_pivot.global_position)
