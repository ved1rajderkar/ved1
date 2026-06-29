extends CharacterBody3D

signal item_picked(item_name: String)
signal item_dropped(item_name: String)
signal negotiation_started(customer: Node3D)

@export var move_speed: float = 8.0
@export var sprint_speed: float = 12.0
@export var mouse_sensitivity: float = 0.0005
@export var zoom_speed: float = 2.0
@export var zoom_min: float = 4.0
@export var zoom_max: float = 15.0
@export var pitch_min: float = -65.0
@export var pitch_max: float = -20.0
@export var yaw_min: float = -100.0
@export var yaw_max: float = 100.0
@export var gravity_force: float = -25.0
@export var stack_spacing: float = 0.25
@export var max_held_items: int = 5

var yaw: float = 0.0
var pitch: float = -40.0
var current_zoom: float = 10.0
var mouse_captured: bool = false
var held_items: Array[Node3D] = []
var is_negotiating: bool = false
var negotiation_customer: Node3D = null

const BOUNDS_MIN := Vector3(-13.0, 0.0, -9.0)
const BOUNDS_MAX := Vector3(13.0, 5.0, 9.0)

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var item_stack: Marker3D = $ItemStack if has_node("ItemStack") else null

var _item_scene_phone: PackedScene = null
var _item_scene_laptop: PackedScene = null
var _item_scene_console: PackedScene = null

var _anim_idle_name: String = "idle"
var _anim_walk_name: String = "run"
var _was_moving: bool = false


func _ready() -> void:
	_load_item_scenes()
	current_zoom = 10.0
	camera.position.z = current_zoom
	_ensure_item_stack()
	_ensure_animation_player()
	_try_load_animations()
	_connect_register_signals()


func _load_item_scenes() -> void:
	if ResourceLoader.exists("res://assets/devices/red_dragon_headset.glb"):
		_item_scene_phone = load("res://assets/devices/red_dragon_headset.glb")
	if ResourceLoader.exists("res://assets/devices/low-poly-modern-laptop-with-closing-animation/source/laptop.glb"):
		_item_scene_laptop = load("res://assets/devices/low-poly-modern-laptop-with-closing-animation/source/laptop.glb")
	if ResourceLoader.exists("res://assets/devices/handheld_console_ps_vita_lite_inspired.glb"):
		_item_scene_console = load("res://assets/devices/handheld_console_ps_vita_lite_inspired.glb")


func _ensure_item_stack() -> void:
	if item_stack == null:
		item_stack = Marker3D.new()
		item_stack.name = "ItemStack"
		item_stack.position = Vector3(0.0, 0.5, -0.3)
		add_child(item_stack)
		item_stack.owner = get_tree().edited_scene_root if get_tree().edited_scene_root else null


func _ensure_animation_player() -> void:
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)
		animation_player.owner = get_tree().edited_scene_root if get_tree().edited_scene_root else null


func _try_load_animations() -> void:
	if animation_player == null:
		return
	if animation_player.has_animation_library("") and animation_player.get_animation_library("").get_animation_count() > 0:
		return
	var anim_entries: Array[Array] = [
		["idle", "res://assets/player/Animations/idle.fbx"],
		["run", "res://assets/player/Animations/run.fbx"],
	]
	var lib: AnimationLibrary = AnimationLibrary.new()
	animation_player.add_animation_library("", lib)
	for entry: Array in anim_entries:
		var anim_name: String = entry[0]
		var fbx_path: String = entry[1]
		if not ResourceLoader.exists(fbx_path):
			continue
		var scene: PackedScene = load(fbx_path) as PackedScene
		if scene == null:
			continue
		var temp_instance: Node = scene.instantiate()
		var found_anim: Animation = _extract_animation_from(temp_instance, anim_name)
		if found_anim == null:
			found_anim = _find_any_animation(temp_instance)
		if found_anim != null:
			lib.add_animation(anim_name, found_anim)
		_node_queue_free(temp_instance)
	if lib.get_animation_count() > 0:
		var first_anim: String = lib.get_animation_name(0)
		animation_player.play(first_anim)


func _extract_animation_from(node: Node, anim_name: String) -> Animation:
	if node is AnimationPlayer:
		if node.has_animation(anim_name):
			return node.get_animation(anim_name)
		if node.get_animation_library_count() > 0:
			for lib_idx in range(node.get_animation_library_count()):
				var lib_name: String = node.get_animation_library_name(lib_idx)
				var library: AnimationLibrary = node.get_animation_library(lib_idx)
				if library.has_animation(anim_name):
					return library.get_animation(anim_name)
	for child in node.get_children():
		var result: Animation = _extract_animation_from(child, anim_name)
		if result != null:
			return result
	return null


func _find_any_animation(node: Node) -> Animation:
	if node is AnimationPlayer:
		if node.get_animation_count() > 0:
			return node.get_animation(node.get_animation_name(0))
		if node.get_animation_library_count() > 0:
			var library: AnimationLibrary = node.get_animation_library(0)
			if library.get_animation_count() > 0:
				return library.get_animation(library.get_animation_name(0))
	for child in node.get_children():
		var result: Animation = _find_any_animation(child)
		if result != null:
			return result
	return null


func _node_queue_free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _connect_register_signals() -> void:
	var registers: Array[Node] = get_tree().get_nodes_in_group("register_area")
	for register_node: Node in registers:
		if register_node.has_signal("negotiation_started"):
			register_node.negotiation_started.connect(_on_negotiation_started)


func _get_ui():
	var ui = Engine.get_meta("UIManager", null)
	if ui:
		return ui
	var tree = get_tree()
	if tree:
		return tree.root.get_node_or_null("Main/UIManager")
	return null


func _unhandled_input(event: InputEvent) -> void:
	if is_negotiating:
		return

	if GameManager.state != GameManager.State.PLAYING:
		if event.is_action_pressed("pause_game") and GameManager.state == GameManager.State.PAUSED:
			GameManager.resume_game()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom = clampf(current_zoom - zoom_speed, zoom_min, zoom_max)
			camera.position.z = current_zoom
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom = clampf(current_zoom + zoom_speed, zoom_min, zoom_max)
			camera.position.z = current_zoom
			return
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if mouse_captured:
				_release_mouse()
			else:
				_capture_mouse()
			return

	if event is InputEventMouseMotion and mouse_captured:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		yaw = clampf(yaw, deg_to_rad(yaw_min), deg_to_rad(yaw_max))
		pitch = clampf(pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
		return

	if event.is_action_pressed("pause_game"):
		GameManager.toggle_pause()
		return

	if event.is_action_pressed("open_build_menu"):
		var ui = _get_ui()
		if ui and ui.has_method("toggle_build_menu"):
			ui.toggle_build_menu()
		return

	if event.is_action_pressed("speed_1x"):
		GameManager.set_speed(1.0)
		return
	if event.is_action_pressed("speed_2x"):
		GameManager.set_speed(2.0)
		return
	if event.is_action_pressed("speed_3x"):
		GameManager.set_speed(3.0)
		return
	if event.is_action_pressed("speed_4x"):
		GameManager.set_speed(4.0)
		return


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	if is_negotiating:
		velocity = Vector3.ZERO
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	var forward := -Vector3.FORWARD.rotated(Vector3.UP, yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
	var move_dir := (right * input.x + forward * input.y).normalized()

	var speed := sprint_speed if Input.is_action_pressed("sprint") else move_speed

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	if not is_on_floor():
		velocity.y += gravity_force * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_update_camera()
	_update_animation(move_dir)
	_rotate_to_movement(move_dir, delta)


func _update_animation(move_dir: Vector3) -> void:
	if animation_player == null:
		return
	var is_moving: bool = move_dir.length_squared() > 0.01
	if is_moving == _was_moving:
		return
	_was_moving = is_moving
	if is_moving:
		if animation_player.has_animation(_anim_walk_name):
			if animation_player.current_animation != _anim_walk_name:
				animation_player.play(_anim_walk_name, 0.2)
	else:
		if animation_player.has_animation(_anim_idle_name):
			if animation_player.current_animation != _anim_idle_name:
				animation_player.play(_anim_idle_name, 0.3)


func _rotate_to_movement(move_dir: Vector3, delta: float) -> void:
	if move_dir.length_squared() < 0.01:
		return
	var target_yaw: float = atan2(move_dir.x, move_dir.z)
	var current_yaw: float = rotation.y
	var blended_yaw: float = lerp_angle(current_yaw, target_yaw, 10.0 * delta)
	rotation.y = blended_yaw


func pick_up_item(item_type: String) -> bool:
	if held_items.size() >= max_held_items:
		return false
	var item_scene: PackedScene = _get_item_scene(item_type)
	if item_scene == null:
		return false
	var item_instance: Node3D = item_scene.instantiate() as Node3D
	if item_instance == null:
		return false
	item_instance.name = "HeldItem_%d_%s" % [held_items.size(), item_type]
	item_instance.set_meta("item_type", item_type)
	_scale_item_for_holding(item_instance)
	item_stack.add_child(item_instance)
	var stack_index: int = held_items.size()
	item_instance.position = Vector3(0.0, stack_index * stack_spacing, 0.0)
	held_items.append(item_instance)
	item_picked.emit(item_type)
	return true


func drop_item(item_type: String = "") -> bool:
	if held_items.is_empty():
		return false
	var item_to_drop: Node3D = null
	if item_type.is_empty():
		item_to_drop = held_items.back()
	else:
		for item: Node3D in held_items:
			if item.get_meta("item_type", "") == item_type:
				item_to_drop = item
				break
	if item_to_drop == null:
		return false
	var drop_pos: Vector3 = global_position + Vector3(0.0, 0.5, 0.0) + Vector3.FORWARD.rotated(Vector3.UP, yaw) * -1.5
	item_to_drop.get_parent().remove_child(item_to_drop)
	get_tree().current_scene.add_child(item_to_drop)
	item_to_drop.global_position = drop_pos
	held_items.erase(item_to_drop)
	_restack_items()
	item_dropped.emit(item_to_drop.get_meta("item_type", ""))
	return true


func drop_all_items() -> void:
	while not held_items.is_empty():
		drop_item("")


func _restack_items() -> void:
	for i in range(held_items.size()):
		var item: Node3D = held_items[i]
		if item.get_parent() != item_stack:
			item_stack.add_child(item)
		item.position = Vector3(0.0, i * stack_spacing, 0.0)


func _get_item_scene(item_type: String) -> PackedScene:
	match item_type:
		"phone", "headset":
			return _item_scene_phone
		"laptop":
			return _item_scene_laptop
		"console":
			return _item_scene_console
		_:
			return _item_scene_phone


func _scale_item_for_holding(item: Node3D) -> void:
	item.scale = Vector3(0.3, 0.3, 0.3)
	item.rotation = Vector3.ZERO


func get_held_item_count() -> int:
	return held_items.size()


func get_held_item_types() -> Array[String]:
	var types: Array[String] = []
	for item: Node3D in held_items:
		types.append(item.get_meta("item_type", "unknown"))
	return types


func has_item(item_type: String) -> bool:
	for item: Node3D in held_items:
		if item.get_meta("item_type", "") == item_type:
			return true
	return false


func _on_negotiation_started(customer: Node3D) -> void:
	is_negotiating = true
	negotiation_customer = customer
	negotiation_started.emit(customer)


func end_negotiation() -> void:
	is_negotiating = false
	negotiation_customer = null


func _update_camera() -> void:
	camera_pivot.global_position = global_position + Vector3(0, 0.5, 0)
	camera_pivot.rotation.y = yaw
	camera.rotation.x = pitch
	var desired_z = current_zoom
	var origin = camera_pivot.global_position
	var direction = Vector3(0, 0, 1)
	var space = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(origin, origin + direction * desired_z)
	params.collision_mask = 1
	var result = space.intersect_ray(params)
	if result:
		var hit_dist = result.position.distance_to(origin) - 0.2
		camera.position.z = max(0.5, hit_dist)
	else:
		camera.position.z = desired_z


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
