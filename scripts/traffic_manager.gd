extends Node3D

signal car_stopped(car: Node3D)
signal car_resumed(car: Node3D)

@export var base_speed: float = 6.0
@export var speed_variation: float = 2.0
@export var stop_distance: float = 4.0
@export var player_stop_distance: float = 3.5
@export var max_active_cars: int = 12
@export var car_scale_min: float = 0.8
@export var car_scale_max: float = 1.1

var active_cars: Array[Node3D] = []
var car_road_index: Array[int] = []
var car_speeds: Array[float] = []
var car_point_index: Array[int] = []
var car_forward: Array[bool] = []
var car_stopped_flags: Array[bool] = []
var player_node: Node3D = null

var road_paths: Array = []
var _car_scenes: Array[PackedScene] = []
var _car_meshes_loaded: bool = false
var _path_gen_timer: float = 0.0
const PATH_REGEN_INTERVAL: float = 30.0


func _ready() -> void:
	_load_car_meshes()
	_generate_all_paths()
	_spawn_initial_cars()
	_find_player()


func _load_car_meshes() -> void:
	if _car_meshes_loaded:
		return
	var car_paths_list: Array[String] = [
		"res://assets/vichecles/sedan.glb",
		"res://assets/vichecles/taxi.glb",
		"res://assets/vichecles/hatchback-sports.glb",
		"res://assets/vichecles/sedan-sports.glb",
		"res://assets/vichecles/suv.glb",
		"res://assets/vichecles/van.glb",
		"res://assets/vichecles/delivery.glb",
		"res://assets/vichecles/ambulance.glb",
		"res://assets/vichecles/police.glb",
	]
	for path: String in car_paths_list:
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path) as PackedScene
			if scene != null:
				_car_scenes.append(scene)
	_car_meshes_loaded = true


func _find_player() -> void:
	player_node = get_tree().root.get_node_or_null("Main/Player")
	if player_node == null:
		player_node = get_tree().root.get_node_or_null("Main/WorldBuilder/Characters/Player")


func _generate_all_paths() -> void:
	road_paths.clear()
	road_paths.append(_generate_loop_path(Vector3(0, 0, 0), 30.0, 8))
	road_paths.append(_generate_loop_path(Vector3(0, 0, 0), 30.0, 8, TAU * 0.25))
	road_paths.append(_generate_loop_path(Vector3(0, 0, 0), 45.0, 10, TAU * 0.5))
	road_paths.append(_generate_loop_path(Vector3(0, 0, 0), 45.0, 10, TAU * 0.75))
	road_paths.append(_generate_rectangle_path(Vector3(-20, 0, -20), Vector3(20, 0, 20)))
	road_paths.append(_generate_rectangle_path(Vector3(-35, 0, -35), Vector3(35, 0, 35)))
	road_paths.append(_generate_loop_path(Vector3(25, 0, 25), 15.0, 6))
	road_paths.append(_generate_loop_path(Vector3(-25, 0, -25), 15.0, 6))


func _generate_loop_path(center: Vector3, radius: float, point_count: int, angle_offset: float = 0.0) -> Array:
	var points: Array = []
	for i in range(point_count):
		var angle: float = angle_offset + (float(i) / float(point_count)) * TAU
		var px: float = center.x + cos(angle) * radius
		var pz: float = center.z + sin(angle) * radius
		points.append(Vector3(px, 0.1, pz))
	return points


func _generate_rectangle_path(tl: Vector3, br: Vector3) -> Array:
	var points: Array = []
	var margin: float = 2.0
	points.append(Vector3(tl.x + margin, 0.1, tl.z + margin))
	points.append(Vector3(br.x - margin, 0.1, tl.z + margin))
	points.append(Vector3(br.x - margin, 0.1, br.z - margin))
	points.append(Vector3(tl.x + margin, 0.1, br.z - margin))
	return points


func _spawn_initial_cars() -> void:
	var initial_count: int = mini(max_active_cars, 8)
	for i in range(initial_count):
		_spawn_car_on_random_path()


func _spawn_car_on_random_path() -> void:
	if active_cars.size() >= max_active_cars:
		return
	if _car_scenes.is_empty() or road_paths.is_empty():
		return
	var path_index: int = randi() % road_paths.size()
	var path_points: Array = road_paths[path_index]
	if path_points.size() < 2:
		return
	var start_point_index: int = randi() % path_points.size()
	var car_scene: PackedScene = _car_scenes[randi() % _car_scenes.size()]
	var car_instance: Node3D = car_scene.instantiate() as Node3D
	if car_instance == null:
		return
	var start_pos: Vector3 = path_points[start_point_index]
	car_instance.position = start_pos
	var next_index: int = (start_point_index + 1) % path_points.size()
	var forward_dir: Vector3 = (path_points[next_index] - start_pos).normalized()
	if forward_dir.length_squared() > 0.01:
		car_instance.rotation.y = atan2(forward_dir.x, forward_dir.z)
	var car_scale: float = randf_range(car_scale_min, car_scale_max)
	car_instance.scale = Vector3(car_scale, car_scale, car_scale)
	add_child(car_instance)
	var car_speed: float = base_speed + randf_range(-speed_variation, speed_variation)
	active_cars.append(car_instance)
	car_road_index.append(path_index)
	car_speeds.append(car_speed)
	car_point_index.append(start_point_index)
	car_forward.append(randi() % 2 == 0)
	car_stopped_flags.append(false)


func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_path_gen_timer += delta
	if _path_gen_timer >= PATH_REGEN_INTERVAL:
		_path_gen_timer = 0.0
		_respawn_offscreen_cars()
	_update_all_cars(delta)


func _update_all_cars(delta: float) -> void:
	var player_pos: Vector3 = Vector3.ZERO
	var has_player: bool = false
	if player_node != null and is_instance_valid(player_node):
		player_pos = player_node.global_position
		has_player = true
	for i in range(active_cars.size() - 1, -1, -1):
		var car: Node3D = active_cars[i]
		if not is_instance_valid(car):
			_remove_car_at(i)
			continue
		_update_single_car(car, i, delta, has_player, player_pos)


func _update_single_car(car: Node3D, index: int, delta: float, has_player: bool, player_pos: Vector3) -> void:
	var road_idx: int = car_road_index[index]
	if road_idx < 0 or road_idx >= road_paths.size():
		return
	var path_points: Array = road_paths[road_idx]
	if path_points.size() < 2:
		return
	var current_idx: int = car_point_index[index]
	var target_idx: int = _get_next_point_index(current_idx, path_points.size(), car_forward[index])
	var target_pos: Vector3 = path_points[target_idx]
	var to_target: Vector3 = target_pos - car.position
	var dist_to_target: float = Vector2(to_target.x, to_target.z).length()
	var player_too_close: bool = false
	if has_player:
		var dist_to_player: float = Vector2(car.global_position.x - player_pos.x, car.global_position.z - player_pos.z).length()
		if dist_to_player < player_stop_distance:
			var car_forward_dir: Vector3 = (target_pos - car.position).normalized()
			var to_player: Vector3 = (player_pos - car.position).normalized()
			var dot: float = car_forward_dir.dot(to_player)
			if dot > 0.3:
				player_too_close = true
	var car_ahead: bool = false
	for j in range(active_cars.size()):
		if j == index:
			continue
		var other_car: Node3D = active_cars[j]
		if not is_instance_valid(other_car):
			continue
		var dist_to_other: float = Vector2(car.global_position.x - other_car.global_position.x, car.global_position.z - other_car.global_position.z).length()
		if dist_to_other < stop_distance:
			var car_dir: Vector3 = (target_pos - car.position).normalized()
			var to_other: Vector3 = (other_car.global_position - car.global_position).normalized()
			var dot_product: float = car_dir.dot(to_other)
			if dot_product > 0.5:
				car_ahead = true
				break
	var should_stop: bool = player_too_close or car_ahead
	if should_stop and not car_stopped_flags[index]:
		car_stopped_flags[index] = true
		car_stopped.emit(car)
	elif not should_stop and car_stopped_flags[index]:
		car_stopped_flags[index] = false
		car_resumed.emit(car)
	if car_stopped_flags[index]:
		return
	var speed: float = car_speeds[index]
	var move_vector: Vector3 = to_target.normalized() * speed * delta
	var horizontal_move: Vector3 = Vector3(move_vector.x, 0.0, move_vector.z)
	car.position += horizontal_move
	var look_dir: Vector3 = Vector3(to_target.x, 0.0, to_target.z).normalized()
	if look_dir.length_squared() > 0.01:
		var target_rotation: float = atan2(look_dir.x, look_dir.z)
		car.rotation.y = lerp_angle(car.rotation.y, target_rotation, 5.0 * delta)
	if dist_to_target < 1.5:
		car_point_index[index] = target_idx


func _get_next_point_index(current: int, total: int, forward: bool) -> int:
	if forward:
		return (current + 1) % total
	else:
		return (current - 1 + total) % total


func _remove_car_at(index: int) -> void:
	active_cars.remove_at(index)
	car_road_index.remove_at(index)
	car_speeds.remove_at(index)
	car_point_index.remove_at(index)
	car_forward.remove_at(index)
	car_stopped_flags.remove_at(index)


func _respawn_offscreen_cars() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	for i in range(active_cars.size() - 1, -1, -1):
		var car: Node3D = active_cars[i]
		if not is_instance_valid(car):
			_remove_car_at(i)
			continue
		var cam_pos: Vector3 = cam.global_position
		var dist: float = car.global_position.distance_to(cam_pos)
		if dist > 120.0:
			car.queue_free()
			_remove_car_at(i)
	while active_cars.size() < max_active_cars:
		_spawn_car_on_random_path()


func get_car_count() -> int:
	return active_cars.size()
