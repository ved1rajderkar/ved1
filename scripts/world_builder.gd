extends Node3D

const CITY_MATERIAL_DIR: String = "res://assets/city material"
const DEVICES_DIR: String = "res://assets/devices"
const VEHICLES_DIR: String = "res://assets/vichecles"
const PLAYER_DIR: String = "res://assets/player"
const PLACEHOLDERS_DIR: String = "res://assets/placeholders"

var city_node: Node3D
var devices_node: Node3D
var vehicles_node: Node3D
var characters_node: Node3D
var customers_node: Node3D
var store_node: Node3D

var city_buildings: Array[MeshInstance3D] = []
var parked_vehicles: Array[Node3D] = []
var ai_characters: Array[CharacterBody3D] = []
var active_customers: Array[CharacterBody3D] = []
var shelf_positions: Array[Vector3] = []
var register_node: Node3D = null
var traffic_manager: Node3D = null

@export var city_radius: float = 80.0
@export var city_edge_buffer: float = 25.0
@export var building_count: int = 40
@export var vehicle_count: int = 15
@export var ai_count: int = 8
@export var max_customers: int = 5
@export var customer_spawn_interval: float = 8.0
@export var player_spawn: Vector3 = Vector3(0, 1, 0)

var _customer_spawn_timer: float = 0.0
var _customer_scene: PackedScene = null


func _ready() -> void:
	_create_containers()
	_setup_store()
	_build_city()
	_place_devices()
	_spawn_vehicles()
	_spawn_characters()
	_setup_traffic_manager()
	_spawn_initial_customers()


func _create_containers() -> void:
	city_node = Node3D.new()
	city_node.name = "City"
	add_child(city_node)

	devices_node = Node3D.new()
	devices_node.name = "Devices"
	add_child(devices_node)

	vehicles_node = Node3D.new()
	vehicles_node.name = "Vehicles"
	add_child(vehicles_node)

	characters_node = Node3D.new()
	characters_node.name = "Characters"
	add_child(characters_node)

	customers_node = Node3D.new()
	customers_node.name = "Customers"
	add_child(customers_node)

	store_node = Node3D.new()
	store_node.name = "Store"
	add_child(store_node)


func _setup_store() -> void:
	var shelf_positions_list: Array[Vector3] = [
		Vector3(-6.0, 0.8, -5.0),
		Vector3(-3.0, 0.8, -5.0),
		Vector3(0.0, 0.8, -5.0),
		Vector3(3.0, 0.8, -5.0),
		Vector3(6.0, 0.8, -5.0),
		Vector3(-6.0, 0.8, -2.0),
		Vector3(-3.0, 0.8, -2.0),
	]
	for pos: Vector3 in shelf_positions_list:
		shelf_positions.append(pos)

	register_node = Node3D.new()
	register_node.name = "CashRegister"
	register_node.position = Vector3(0.0, 0.0, 8.5)
	var reg_script: Script = load("res://scripts/register.gd") as Script
	if reg_script:
		register_node.set_script(reg_script)
	store_node.add_child(register_node)

	var counter_mesh: CSGBox3D = CSGBox3D.new()
	counter_mesh.name = "CounterMesh"
	counter_mesh.size = Vector3(6.0, 1.1, 1.2)
	counter_mesh.position = Vector3(0.0, 0.6, 0.0)
	var counter_mat: StandardMaterial3D = StandardMaterial3D.new()
	counter_mat.albedo_color = Color(0.38, 0.35, 0.3)
	counter_mesh.material = counter_mat
	counter_mesh.use_collision = true
	register_node.add_child(counter_mesh)


func _build_city() -> void:
	var buildings: Array[Resource] = _load_folder_assets(CITY_MATERIAL_DIR, ".glb")
	if buildings.is_empty():
		push_warning("WorldBuilder: No city material assets found.")
		return

	var city_grid_size: float = 16.0
	var half_city: int = int(city_radius / city_grid_size)

	for i in range(building_count):
		var res: Resource = buildings[i % buildings.size()]
		if res == null:
			continue

		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.mesh = res.duplicate()
		var pos: Vector3 = _get_city_position(i, half_city, city_grid_size)
		pos.y = 0.0
		mesh_node.position = pos
		mesh_node.rotation.y = randf() * TAU
		var scale_val: float = randf_range(0.8, 1.4)
		mesh_node.scale = Vector3(scale_val, scale_val, scale_val)
		var dist_from_center: float = Vector2(pos.x, pos.z).length()
		if dist_from_center < city_edge_buffer:
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city_node.add_child(mesh_node)
		city_buildings.append(mesh_node)

		_add_collision_to_mesh(mesh_node)

	_decorate_city(buildings)


func _get_city_position(index: int, half_city: int, grid_size: float) -> Vector3:
	var side: int = index % 4
	var ring: int = (index / 4) + 2
	var offset: int = index % 6 - 3

	match side:
		0:
			return Vector3(float(offset) * grid_size, 0, float(ring) * grid_size)
		1:
			return Vector3(float(ring) * grid_size, 0, float(offset) * grid_size)
		2:
			return Vector3(float(-offset) * grid_size, 0, float(-ring) * grid_size)
		3:
			return Vector3(float(-ring) * grid_size, 0, float(-offset) * grid_size)
	return Vector3.ZERO


func _decorate_city(all_buildings: Array[Resource]) -> void:
	var detail_assets: Array[Resource] = []
	for res in all_buildings:
		var path: String = ""
		if res is PackedScene:
			path = res.resource_path
		elif res is Mesh:
			path = res.resource_path
		if "detail" in path.to_lower():
			detail_assets.append(res)

	if detail_assets.is_empty():
		return

	for i in range(10):
		var res: Resource = detail_assets[i % detail_assets.size()]
		if res == null:
			continue
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.mesh = res.duplicate()
		var angle: float = randf() * TAU
		var dist: float = randf_range(city_edge_buffer, city_radius * 0.6)
		mesh_node.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		mesh_node.rotation.y = randf() * TAU
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city_node.add_child(mesh_node)


func _place_devices() -> void:
	var device_assets: Array[Resource] = _load_folder_assets(DEVICES_DIR, ".glb")
	if device_assets.is_empty():
		push_warning("WorldBuilder: No device assets found.")
		return

	var placement_positions: Array[Vector3] = [
		Vector3(-6, 0.8, -5),
		Vector3(-3, 0.8, -5),
		Vector3(0, 0.8, -5),
		Vector3(3, 0.8, -5),
		Vector3(6, 0.8, -5),
		Vector3(-6, 0.8, -2),
		Vector3(0, 1.5, 0),
	]

	for i in range(min(device_assets.size(), placement_positions.size())):
		var res: Resource = device_assets[i]
		if res == null:
			continue

		var instance: Node3D
		if res is PackedScene:
			instance = res.instantiate()
		else:
			instance = MeshInstance3D.new()
			instance.mesh = res

		instance.position = placement_positions[i]
		instance.rotation.y = randf() * TAU
		var dev_scale: float = randf_range(0.6, 1.2)
		instance.scale = Vector3(dev_scale, dev_scale, dev_scale)
		devices_node.add_child(instance)


func _spawn_vehicles() -> void:
	var vehicle_assets: Array[Resource] = _load_folder_assets(VEHICLES_DIR, ".glb")
	if vehicle_assets.is_empty():
		push_warning("WorldBuilder: No vehicle assets found.")
		return

	var drivable_vehicles: Array[Resource] = []
	for res in vehicle_assets:
		var path: String = ""
		if res is PackedScene:
			path = res.resource_path
		elif res is Mesh:
			path = res.resource_path
		if "debris" in path.to_lower() or "wheel" in path.to_lower() or "cone" in path.to_lower() or "box" in path.to_lower():
			continue
		drivable_vehicles.append(res)

	if drivable_vehicles.is_empty():
		drivable_vehicles = vehicle_assets

	for i in range(vehicle_count):
		var res: Resource = drivable_vehicles[i % drivable_vehicles.size()]
		if res == null:
			continue

		var instance: Node3D
		if res is PackedScene:
			instance = res.instantiate()
		else:
			instance = MeshInstance3D.new()
			instance.mesh = res

		var road_pos: Vector3 = _get_vehicle_position(i)
		instance.position = road_pos
		instance.rotation.y = randf() * TAU
		var veh_scale: float = randf_range(0.8, 1.1)
		instance.scale = Vector3(veh_scale, veh_scale, veh_scale)
		vehicles_node.add_child(instance)
		parked_vehicles.append(instance)


func _get_vehicle_position(index: int) -> Vector3:
	var side: int = index % 4
	var lane: float = 20.0 + (index % 3) * 4.0
	var along: float = (index * 7.0) - 40.0
	along = fmod(along, 60.0) - 30.0

	match side:
		0:
			return Vector3(along, 0.05, lane)
		1:
			return Vector3(lane, 0.05, along)
		2:
			return Vector3(-along, 0.05, -lane)
		3:
			return Vector3(-lane, 0.05, -along)
	return Vector3.ZERO


func _spawn_characters() -> void:
	var model_assets: Array[Resource] = _load_assets_recursive(PLAYER_DIR, ".fbx")
	var skin_assets: Array[Resource] = _load_assets_recursive(PLAYER_DIR, ".png")

	var model: Resource = null
	for res in model_assets:
		var path: String = ""
		if res is PackedScene:
			path = res.resource_path
		elif res is Mesh:
			path = res.resource_path
		if "character" in path.to_lower():
			model = res
			break

	if model == null and not model_assets.is_empty():
		model = model_assets[0]

	var player_node: CharacterBody3D = _create_character(model, player_spawn, true)
	if player_node:
		characters_node.add_child(player_node)
		var cam: Camera3D = _find_camera()
		if cam:
			player_node.add_child(cam)

	for i in range(ai_count):
		var ai_pos: Vector3 = _get_ai_spawn_position(i)
		var ai_skin: Texture2D = skin_assets[i % skin_assets.size()] if not skin_assets.is_empty() else null
		var ai_node: CharacterBody3D = _create_character(model, ai_pos, false, ai_skin)
		if ai_node:
			characters_node.add_child(ai_node)
			ai_characters.append(ai_node)


func _create_character(model_resource: Resource, pos: Vector3, is_player: bool, skin: Texture2D = null) -> CharacterBody3D:
	var character: CharacterBody3D = CharacterBody3D.new()
	character.position = pos
	character.collision_layer = 2 if is_player else 4
	character.collision_mask = 1

	if is_player:
		var existing_player: Node = get_tree().root.get_node_or_null("Main/Player")
		if existing_player:
			existing_player.queue_free()

		var player_script: Script = load("res://scripts/player_controller.gd") as Script
		if player_script:
			character.set_script(player_script)

		var body_mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.5, 1.0, 0.5)
		body_mesh.mesh = box
		body_mesh.position.y = 0.5
		var body_mat: StandardMaterial3D = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.2, 0.5, 0.9)
		body_mesh.material = body_mat
		character.add_child(body_mesh)

		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: CapsuleShape3D = CapsuleShape3D.new()
		shape.radius = 0.25
		shape.height = 1.0
		collision.shape = shape
		collision.position.y = 0.5
		character.add_child(collision)

		var item_stack: Marker3D = Marker3D.new()
		item_stack.name = "ItemStack"
		item_stack.position = Vector3(0.0, 0.5, -0.3)
		character.add_child(item_stack)

		var anim_player: AnimationPlayer = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		character.add_child(anim_player)

		var pivot: Node3D = Node3D.new()
		pivot.name = "CameraPivot"
		pivot.position = Vector3(0, 0.5, 0)
		character.add_child(pivot)

		var cam: Camera3D = Camera3D.new()
		cam.name = "Camera3D"
		cam.position = Vector3(0, 2, 4)
		cam.current = true
		cam.fov = 60.0
		cam.near = 0.1
		cam.far = 45.0
		pivot.add_child(cam)

		var raycast: RayCast3D = RayCast3D.new()
		raycast.target_position = Vector3(0, 0, -500)
		raycast.collision_mask = 3
		cam.add_child(raycast)
	else:
		var body_mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.4, 0.9, 0.4)
		body_mesh.mesh = box
		body_mesh.position.y = 0.45
		var body_mat: StandardMaterial3D = StandardMaterial3D.new()
		body_mat.albedo_color = Color(randf_range(0.3, 0.8), randf_range(0.3, 0.8), randf_range(0.3, 0.8))
		if skin:
			body_mat.albedo_texture = skin
		body_mesh.material = body_mat
		character.add_child(body_mesh)

		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: CapsuleShape3D = CapsuleShape3D.new()
		shape.radius = 0.2
		shape.height = 0.9
		collision.shape = shape
		collision.position.y = 0.45
		character.add_child(collision)

		character.set_meta("is_ai", true)
		character.set_meta("skin", skin)
		character.set_meta("wander_target", pos)

	return character


func _find_camera() -> Camera3D:
	var existing_cam: Camera3D = get_tree().root.get_node_or_null("Main/Player/CameraPivot/Camera3D")
	if existing_cam:
		return existing_cam.get_parent().get_parent()
	return null


func _get_ai_spawn_position(index: int) -> Vector3:
	var angle: float = (float(index) / float(ai_count)) * TAU
	var dist: float = randf_range(5.0, 12.0)
	return Vector3(cos(angle) * dist, 0, sin(angle) * dist)


func _setup_traffic_manager() -> void:
	var traffic_script: Script = load("res://scripts/traffic_manager.gd") as Script
	if traffic_script:
		traffic_manager = Node3D.new()
		traffic_manager.name = "TrafficManager"
		traffic_manager.set_script(traffic_script)
		vehicles_node.add_child(traffic_manager)


func _spawn_initial_customers() -> void:
	var initial_count: int = mini(max_customers, 3)
	for i in range(initial_count):
		_spawn_customer()


func _spawn_customer() -> void:
	if active_customers.size() >= max_customers:
		return
	var customer_script: Script = load("res://scripts/customer.gd") as Script
	if customer_script == null:
		return
	var customer: CharacterBody3D = CharacterBody3D.new()
	customer.set_script(customer_script)
	customer.name = "Customer_%d" % active_customers.size()
	customer.collision_layer = 4
	customer.collision_mask = 1
	var entrance_pos: Vector3 = _get_customer_entrance_position()
	customer.position = entrance_pos
	customers_node.add_child(customer)
	active_customers.append(customer)
	var shelf_nodes: Array[Node3D] = _get_shelf_nodes()
	customer.initialize(entrance_pos, shelf_nodes, register_node)
	customer.customer_left.connect(_on_customer_left)


func _get_customer_entrance_position() -> Vector3:
	var side: int = randi() % 2
	match side:
		0:
			return Vector3(randf_range(-2.0, 2.0), 0.0, 12.0)
		1:
			return Vector3(randf_range(-2.0, 2.0), 0.0, 12.0)
	return Vector3(0.0, 0.0, 12.0)


func _get_shelf_nodes() -> Array[Node3D]:
	var shelves: Array[Node3D] = []
	for pos: Vector3 in shelf_positions:
		var shelf_marker: Node3D = Node3D.new()
		shelf_marker.position = pos
		store_node.add_child(shelf_marker)
		shelves.append(shelf_marker)
	return shelves


func _on_customer_left(customer: Node3D, _was_satisfied: bool) -> void:
	active_customers.erase(customer)


func _process(delta: float) -> void:
	_update_ai_characters(delta)
	_customer_spawn_timer += delta
	if _customer_spawn_timer >= customer_spawn_interval:
		_customer_spawn_timer = 0.0
		if GameManager.state == GameManager.State.PLAYING:
			_spawn_customer()
	_cleanup_dead_customers()


func _cleanup_dead_customers() -> void:
	for i in range(active_customers.size() - 1, -1, -1):
		if not is_instance_valid(active_customers[i]):
			active_customers.remove_at(i)


func _update_ai_characters(delta: float) -> void:
	for ai in ai_characters:
		if not is_instance_valid(ai):
			continue
		if ai.get_meta("is_ai", false):
			_wander_ai(ai, delta)


func _wander_ai(ai: CharacterBody3D, delta: float) -> void:
	var target: Vector3 = ai.get_meta("wander_target", Vector3.ZERO)
	var dist: float = ai.global_position.distance_to(target)

	if dist < 1.0:
		var new_target: Vector3 = _get_ai_spawn_position(randi() % ai_count)
		new_target.x += randf_range(-5, 5)
		new_target.z += randf_range(-5, 5)
		ai.set_meta("wander_target", new_target)
		target = new_target

	var direction: Vector3 = (target - ai.global_position).normalized()
	ai.velocity = direction * 2.0
	ai.velocity.y = -10.0
	ai.move_and_slide()

	if direction.length() > 0.1:
		ai.rotation.y = atan2(direction.x, direction.z)


func replace_placeholder(placeholder_name: String, model_resource: Resource) -> void:
	var placeholder_scene: PackedScene = load(PLACEHOLDERS_DIR.path_join(placeholder_name + ".tscn"))
	if placeholder_scene == null:
		push_warning("WorldBuilder: Placeholder not found: %s" % placeholder_name)
		return

	var root: Node3D = get_tree().root.get_node_or_null("Main")
	if root == null:
		return

	_replace_recursive(root, placeholder_scene, model_resource)


func _replace_recursive(node: Node, target_scene: PackedScene, replacement: Resource) -> void:
	for child in node.get_children():
		if child.scene_file_path == target_scene.resource_path:
			var new_instance: Node3D
			if replacement is PackedScene:
				new_instance = replacement.instantiate()
			else:
				new_instance = MeshInstance3D.new()
				new_instance.mesh = replacement
			new_instance.global_position = child.global_position
			new_instance.global_rotation = child.global_rotation
			new_instance.scale = child.scale
			node.add_child(new_instance)
			child.queue_free()
		else:
			_replace_recursive(child, target_scene, replacement)


func get_city_buildings() -> Array[MeshInstance3D]:
	return city_buildings


func get_parked_vehicles() -> Array[Node3D]:
	return parked_vehicles


func get_ai_characters() -> Array[CharacterBody3D]:
	return ai_characters


func get_active_customers() -> Array[CharacterBody3D]:
	return active_customers


func get_register() -> Node3D:
	return register_node


func get_shelf_positions() -> Array[Vector3]:
	return shelf_positions


func _load_folder_assets(dir_path: String, extension: String) -> Array[Resource]:
	var results: Array[Resource] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("WorldBuilder: Cannot open directory: %s" % dir_path)
		return results

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var full_path: String = dir_path.path_join(file_name)
			if file_name.ends_with(extension):
				var res: Resource = load(full_path)
				if res:
					results.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _load_assets_recursive(dir_path: String, extension: String) -> Array[Resource]:
	var results: Array[Resource] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var sub_results: Array[Resource] = _load_assets_recursive(dir_path.path_join(file_name), extension)
				results.append_array(sub_results)
		else:
			if file_name.ends_with(extension):
				var full_path: String = dir_path.path_join(file_name)
				var res: Resource = load(full_path)
				if res:
					results.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _add_collision_to_mesh(mesh_node: MeshInstance3D) -> void:
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	static_body.position = mesh_node.position
	static_body.rotation = mesh_node.rotation
	static_body.scale = mesh_node.scale

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(6.0, 8.0, 6.0)
	collision.shape = shape
	collision.position.y = 4.0
	static_body.add_child(collision)

	city_node.add_child(static_body)
