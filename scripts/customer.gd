extends CharacterBody3D

signal reached_shelf(customer: Node3D, shelf: Node3D)
signal reached_register(customer: Node3D)
signal negotiation_needed(customer: Node3D, item_type: String)
signal customer_left(customer: Node3D, was_satisfied: bool)

enum State {
	WALK_TO_SHELF,
	PICK_ITEM,
	WALK_TO_REGISTER,
	NEGOTIATE,
	LEAVE
}

@export var walk_speed: float = 3.0
@export var pickup_range: float = 1.5
@export var register_range: float = 1.8
@export var shelf_wait_time: float = 2.0
@export var negotiate_timeout: float = 15.0
@export var gravity_force: float = -25.0

var current_state: State = State.WALK_TO_SHELF
var target_shelf: Node3D = null
var target_register: Node3D = null
var selected_item_type: String = ""
var held_item_node: Node3D = null
var shelf_wait_timer: float = 0.0
var negotiate_timer: float = 0.0
var is_satisfied: bool = false
var entrance_position: Vector3 = Vector3.ZERO

var _item_scene_phone: PackedScene = null
var _item_scene_laptop: PackedScene = null
var _item_scene_console: PackedScene = null

var _body_mesh: MeshInstance3D = null
var _original_color: Color = Color.WHITE
var _flash_timer: float = 0.0
var _is_flashing: bool = false


func _ready() -> void:
	entrance_position = global_position
	_load_item_scenes()
	_ensure_body_mesh()
	add_to_group("customers")


func _load_item_scenes() -> void:
	if ResourceLoader.exists("res://assets/devices/red_dragon_headset.glb"):
		_item_scene_phone = load("res://assets/devices/red_dragon_headset.glb")
	if ResourceLoader.exists("res://assets/devices/low-poly-modern-laptop-with-closing-animation/source/laptop.glb"):
		_item_scene_laptop = load("res://assets/devices/low-poly-modern-laptop-with-closing-animation/source/laptop.glb")
	if ResourceLoader.exists("res://assets/devices/handheld_console_ps_vita_lite_inspired.glb"):
		_item_scene_console = load("res://assets/devices/handheld_console_ps_vita_lite_inspired.glb")


func _ensure_body_mesh() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			_body_mesh = child
			if _body_mesh.material_override is StandardMaterial3D:
				_original_color = _body_mesh.material_override.albedo_color
			elif _body_mesh.get_surface_override_material(0) is StandardMaterial3D:
				_original_color = _body_mesh.get_surface_override_material(0).albedo_color
			return
	_body_mesh = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.4, 0.9, 0.4)
	_body_mesh.mesh = box
	_body_mesh.position.y = 0.45
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(randf_range(0.3, 0.8), randf_range(0.3, 0.8), randf_range(0.3, 0.8))
	_body_mesh.material_override = mat
	_original_color = mat.albedo_color
	add_child(_body_mesh)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 0.9
	collision.shape = shape
	collision.position.y = 0.45
	add_child(collision)


func initialize(entrance: Vector3, shelves: Array[Node3D], register: Node3D = null) -> void:
	entrance_position = entrance
	global_position = entrance
	if shelves.is_empty():
		target_shelf = null
		current_state = State.LEAVE
		return
	target_shelf = shelves[randi() % shelves.size()]
	target_register = register
	_select_random_item()


func _select_random_item() -> void:
	var item_options: Array[String] = ["phone", "laptop", "console"]
	var weights: Array[float] = [0.5, 0.3, 0.2]
	var roll: float = randf()
	var cumulative: float = 0.0
	for i in range(item_options.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			selected_item_type = item_options[i]
			return
	selected_item_type = "phone"


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	if _is_flashing:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_is_flashing = false
			_set_color(_original_color)

	match current_state:
		State.WALK_TO_SHELF:
			_state_walk_to_shelf(delta)
		State.PICK_ITEM:
			_state_pick_item(delta)
		State.WALK_TO_REGISTER:
			_state_walk_to_register(delta)
		State.NEGOTIATE:
			_state_negotiate(delta)
		State.LEAVE:
			_state_leave(delta)


func _state_walk_to_shelf(delta: float) -> void:
	if target_shelf == null or not is_instance_valid(target_shelf):
		current_state = State.LEAVE
		return
	var target_pos: Vector3 = target_shelf.global_position
	var direction: Vector3 = target_pos - global_position
	var horizontal_dist: float = Vector2(direction.x, direction.z).length()
	if horizontal_dist < pickup_range:
		velocity = Vector3.ZERO
		current_state = State.PICK_ITEM
		shelf_wait_timer = shelf_wait_time
		reached_shelf.emit(self, target_shelf)
		return
	var move_dir: Vector3 = direction.normalized()
	velocity.x = move_dir.x * walk_speed
	velocity.z = move_dir.z * walk_speed
	if not is_on_floor():
		velocity.y += gravity_force * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_rotate_to_direction(move_dir, delta)


func _state_pick_item(delta: float) -> void:
	velocity = Vector3.ZERO
	shelf_wait_timer -= delta
	if shelf_wait_timer <= 0.0:
		_spawn_held_item()
		current_state = State.WALK_TO_REGISTER
		if target_register == null or not is_instance_valid(target_register):
			current_state = State.LEAVE


func _state_walk_to_register(delta: float) -> void:
	if target_register == null or not is_instance_valid(target_register):
		current_state = State.LEAVE
		return
	var target_pos: Vector3 = target_register.global_position
	var direction: Vector3 = target_pos - global_position
	var horizontal_dist: float = Vector2(direction.x, direction.z).length()
	if horizontal_dist < register_range:
		velocity = Vector3.ZERO
		current_state = State.NEGOTIATE
		negotiate_timer = negotiate_timeout
		reached_register.emit(self)
		negotiation_needed.emit(self, selected_item_type)
		return
	var move_dir: Vector3 = direction.normalized()
	velocity.x = move_dir.x * walk_speed
	velocity.z = move_dir.z * walk_speed
	if not is_on_floor():
		velocity.y += gravity_force * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_rotate_to_direction(move_dir, delta)


func _state_negotiate(delta: float) -> void:
	velocity = Vector3.ZERO
	negotiate_timer -= delta
	if negotiate_timer <= 0.0:
		_handle_negotiation_timeout()


func _state_leave(delta: float) -> void:
	var direction: Vector3 = entrance_position - global_position
	var horizontal_dist: float = Vector2(direction.x, direction.z).length()
	if horizontal_dist < 1.5:
		_cleanup_and_free()
		return
	var move_dir: Vector3 = direction.normalized()
	velocity.x = move_dir.x * walk_speed * 1.2
	velocity.z = move_dir.z * walk_speed * 1.2
	if not is_on_floor():
		velocity.y += gravity_force * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_rotate_to_direction(move_dir, delta)


func _rotate_to_direction(move_dir: Vector3, delta: float) -> void:
	if move_dir.length_squared() < 0.01:
		return
	var target_rotation: float = atan2(move_dir.x, move_dir.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, 8.0 * delta)


func _spawn_held_item() -> void:
	if held_item_node != null:
		return
	var item_scene: PackedScene = _get_item_scene(selected_item_type)
	if item_scene == null:
		return
	var item_instance: Node3D = item_scene.instantiate() as Node3D
	if item_instance == null:
		return
	item_instance.name = "CustomerItem"
	item_instance.set_meta("item_type", selected_item_type)
	item_instance.scale = Vector3(0.25, 0.25, 0.25)
	item_instance.position = Vector3(0.0, 0.7, 0.3)
	add_child(item_instance)
	held_item_node = item_instance


func _remove_held_item() -> void:
	if held_item_node != null and is_instance_valid(held_item_node):
		held_item_node.queue_free()
		held_item_node = null


func _get_item_scene(item_type: String) -> PackedScene:
	match item_type:
		"phone":
			if _item_scene_phone != null:
				return _item_scene_phone
		"laptop":
			if _item_scene_laptop != null:
				return _item_scene_laptop
		"console":
			if _item_scene_console != null:
				return _item_scene_console
	return _item_scene_phone


func _handle_negotiation_timeout() -> void:
	is_satisfied = false
	_flash_red(0.5)
	_remove_held_item()
	current_state = State.LEAVE
	customer_left.emit(self, false)


func accept_deal() -> void:
	is_satisfied = true
	_remove_held_item()
	current_state = State.LEAVE
	customer_left.emit(self, true)


func reject_deal() -> void:
	is_satisfied = false
	_flash_red(1.0)
	_remove_held_item()
	negotiate_timer = 0.0
	current_state = State.LEAVE
	customer_left.emit(self, false)


func _flash_red(duration: float) -> void:
	_is_flashing = true
	_flash_timer = duration
	_set_color(Color(1.0, 0.2, 0.2))


func _set_color(color: Color) -> void:
	if _body_mesh == null:
		return
	var mat: StandardMaterial3D = _body_mesh.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = color
	else:
		var new_mat: StandardMaterial3D = StandardMaterial3D.new()
		new_mat.albedo_color = color
		_body_mesh.material_override = new_mat


func _cleanup_and_free() -> void:
	_remove_held_item()
	queue_free()


func get_selected_item_type() -> String:
	return selected_item_type


func get_state() -> State:
	return current_state


func get_state_name() -> String:
	match current_state:
		State.WALK_TO_SHELF:
			return "WALK_TO_SHELF"
		State.PICK_ITEM:
			return "PICK_ITEM"
		State.WALK_TO_REGISTER:
			return "WALK_TO_REGISTER"
		State.NEGOTIATE:
			return "NEGOTIATE"
		State.LEAVE:
			return "LEAVE"
	return "UNKNOWN"
