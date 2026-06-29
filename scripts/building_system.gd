extends Node3D

signal building_placed(building: Node3D, btype: String)
signal building_removed(building: Node3D)
signal building_upgraded(building: Node3D, new_level: int)
signal placement_started(btype: String)
signal placement_cancelled
signal placement_failed(reason: String)

var placed_buildings: Array[Node3D] = []
var selected_building: Node3D = null
var preview_node: Node3D = null
var is_placing: bool = false
var placing_type: String = ""

var grid_size: float = 4.0
var ground_y: float = 0.05

const BUILDING_ROOT: String = "Buildings"


func _ready() -> void:
	var root: Node3D = Node3D.new()
	root.name = BUILDING_ROOT
	add_child(root)


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		if event.is_action_pressed("ui_cancel"):
			if selected_building:
				deselect_building()
		return

	if event.is_action_pressed("ui_cancel"):
		cancel_placement()
		return

	if event is InputEventMouseMotion:
		_update_preview_position()

	if event.is_action_pressed("confirm_placement"):
		confirm_placement()


func start_placement(btype: String) -> void:
	var data: Dictionary = BuildingData.get_building(btype)
	if data.is_empty():
		placement_failed.emit("Unknown building type.")
		return

	var cost: int = int(data.get("cost", 0))
	if not Economy.can_afford(cost):
		placement_failed.emit("Not enough money! Need $%d." % cost)
		return

	var req_workers: int = int(data.get("workers", 0))
	var req_mats: int = int(data.get("materials", 0))
	if req_workers > 0 and Economy.workers < req_workers:
		placement_failed.emit("Need %d workers (have %d)." % [req_workers, Economy.workers])
		return
	if req_mats > 0 and Economy.materials < req_mats:
		placement_failed.emit("Need %d materials (have %d)." % [req_mats, Economy.materials])
		return

	cancel_placement()
	is_placing = true
	placing_type = btype
	_create_preview(btype)
	placement_started.emit(btype)


func cancel_placement() -> void:
	if not is_placing:
		return
	is_placing = false
	placing_type = ""
	if preview_node:
		preview_node.queue_free()
		preview_node = null
	placement_cancelled.emit()


func confirm_placement() -> void:
	if not is_placing or not preview_node:
		return

	var btype: String = placing_type
	var data: Dictionary = BuildingData.get_building(btype)
	if data.is_empty():
		placement_failed.emit("Unknown building type.")
		return
	var pos: Vector3 = _snap_to_grid(preview_node.global_position)

	if _is_occupied(pos):
		placement_failed.emit("Space already occupied!")
		return

	var cost: int = int(data.get("cost", 0))
	if not Economy.spend_money(cost):
		placement_failed.emit("Not enough money!")
		return

	var workers_needed: int = int(data.get("workers", 0))
	var mats_needed: int = int(data.get("materials", 0))
	if workers_needed > 0:
		Economy.remove_workers(workers_needed)
	if mats_needed > 0:
		Economy.remove_materials(mats_needed)

	var building: Node3D = _create_building(btype, pos)
	placed_buildings.append(building)
	Economy.recalculate_totals()

	preview_node.queue_free()
	preview_node = null
	is_placing = false
	placing_type = ""

	building_placed.emit(building, btype)


func select_building(building: Node3D) -> void:
	deselect_building()
	selected_building = building
	_highlight_building(building, true)


func deselect_building() -> void:
	if selected_building:
		_highlight_building(selected_building, false)
		selected_building = null


func upgrade_building(building: Node3D) -> bool:
	var btype: String = building.get_meta("building_type", "")
	var level: int = building.get_meta("level", 1)
	var max_level: int = BuildingData.get_max_level(btype)
	if level >= max_level:
		placement_failed.emit("Already max level!")
		return false

	var cost: int = BuildingData.get_upgrade_cost(btype, level)
	if not Economy.spend_money(cost):
		placement_failed.emit("Not enough money for upgrade! Need $%d." % cost)
		return false

	building.set_meta("level", level + 1)
	_apply_level_visuals(building)
	Economy.recalculate_totals()
	building_upgraded.emit(building, level + 1)
	return true


func remove_building(building: Node3D) -> void:
	if building not in placed_buildings:
		return
	var btype: String = building.get_meta("building_type", "")
	var data: Dictionary = BuildingData.get_building(btype)
	var refund: int = int(int(data.get("cost", 0)) * 0.5)
	Economy.add_money(refund)
	var workers: int = int(data.get("workers", 0))
	var mats: int = int(data.get("materials", 0))
	if workers > 0:
		Economy.add_workers(workers)
	if mats > 0:
		Economy.add_materials(mats)
	placed_buildings.erase(building)
	Economy.recalculate_totals()
	building.queue_free()
	building_removed.emit(building)


func clear_all() -> void:
	for b in placed_buildings:
		if is_instance_valid(b):
			b.queue_free()
	placed_buildings.clear()
	selected_building = null
	var root: Node3D = get_node_or_null(BUILDING_ROOT)
	if root:
		for child in root.get_children():
			child.queue_free()


func get_all_buildings() -> Array[Node3D]:
	return placed_buildings


func get_building_count(btype: String) -> int:
	var count: int = 0
	for b in placed_buildings:
		if b.get_meta("building_type", "") == btype:
			count += 1
	return count


func get_total_buildings() -> int:
	return placed_buildings.size()


func _create_building(btype: String, pos: Vector3) -> Node3D:
	var data: Dictionary = BuildingData.get_building(btype)
	if data.is_empty():
		data = {"name": "Unknown", "floor_size": Vector3(2, 0.1, 2), "size": Vector3(2, 2, 2), "color": Color(0.6, 0.6, 0.6), "floor_color": Color(0.5, 0.5, 0.5)}
	var container: Node3D = Node3D.new()
	container.name = str(data.get("name", "Building"))
	container.position = pos
	container.set_meta("building_type", btype)
	container.set_meta("level", 1)

	# Floor slab
	var floor_csg: CSGBox3D = CSGBox3D.new()
	var floor_size: Vector3 = data.get("floor_size", Vector3(2, 0.1, 2))
	floor_csg.size = floor_size
	floor_csg.position.y = floor_size.y * 0.5
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = data.get("floor_color", Color(0.5, 0.5, 0.5))
	floor_csg.material = floor_mat
	container.add_child(floor_csg)

	# Main body
	var body_csg: CSGBox3D = CSGBox3D.new()
	var body_size: Vector3 = data.get("size", Vector3(2, 2, 2))
	body_csg.size = body_size
	body_csg.position.y = floor_size.y + body_size.y * 0.5
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = data.get("color", Color(0.6, 0.6, 0.6))
	body_csg.material = body_mat
	body_csg.name = "Body"
	container.add_child(body_csg)

	# Counter top for cash_register
	if btype == "cash_register":
		var counter_csg: CSGBox3D = CSGBox3D.new()
		counter_csg.size = Vector3(body_size.x + 0.3, 0.1, body_size.z + 0.3)
		counter_csg.position.y = floor_size.y + body_size.y + 0.05
		var counter_mat: StandardMaterial3D = StandardMaterial3D.new()
		counter_mat.albedo_color = Color(0.2, 0.2, 0.22)
		counter_csg.material = counter_mat
		container.add_child(counter_csg)

	# Screen for display shelves
	if btype in ["display_shelf", "premium_shelf"]:
		var screen_csg: CSGBox3D = CSGBox3D.new()
		screen_csg.size = Vector3(body_size.x * 0.8, body_size.y * 0.3, 0.05)
		screen_csg.position.y = floor_size.y + body_size.y * 0.7
		screen_csg.position.z = -body_size.z * 0.45
		var screen_mat: StandardMaterial3D = StandardMaterial3D.new()
		screen_mat.albedo_color = Color(0.1, 0.5, 0.9)
		screen_mat.emission_enabled = true
		screen_mat.emission = Color(0.1, 0.4, 0.8)
		screen_mat.emission_energy_multiplier = 0.5
		screen_csg.material = screen_mat
		container.add_child(screen_csg)

	# StaticBody3D for click detection
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "ClickArea"
	static_body.collision_layer = 1
	static_body.collision_mask = 2
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(maxf(body_size.x, floor_size.x), body_size.y + floor_size.y, maxf(body_size.z, floor_size.z))
	collision.shape = shape
	collision.position.y = floor_size.y + body_size.y * 0.5
	static_body.add_child(collision)
	container.add_child(static_body)

	# Area3D for mouse interaction
	var area: Area3D = Area3D.new()
	area.name = "HoverArea"
	area.collision_layer = 0
	area.collision_mask = 2
	var area_collision: CollisionShape3D = CollisionShape3D.new()
	area_collision.shape = shape.duplicate()
	area_collision.position = collision.position
	area.add_child(area_collision)
	container.add_child(area)

	var root: Node3D = get_node_or_null(BUILDING_ROOT)
	if root:
		root.add_child(container)
	else:
		add_child(container)

	return container


func _create_preview(btype: String) -> void:
	var data: Dictionary = BuildingData.get_building(btype)
	preview_node = Node3D.new()
	preview_node.set_meta("building_type", btype)

	var floor_csg: CSGBox3D = CSGBox3D.new()
	floor_csg.size = data.get("floor_size", Vector3(2, 0.1, 2))
	floor_csg.position.y = 0.05
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.5)
	floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_csg.material = floor_mat
	preview_node.add_child(floor_csg)

	var body_csg: CSGBox3D = CSGBox3D.new()
	body_csg.size = data.get("size", Vector3(2, 2, 2))
	body_csg.position.y = 0.1 + body_csg.size.y * 0.5
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.4)
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_csg.material = body_mat
	preview_node.add_child(body_csg)

	add_child(preview_node)


func _update_preview_position() -> void:
	if not preview_node:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var to: Vector3 = from + cam.project_ray_normal(mouse_pos) * 500.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collision_mask = 1
	var result: Dictionary = space.intersect_ray(params)
	if result:
		preview_node.global_position = _snap_to_grid(result.position)


func _snap_to_grid(pos: Vector3) -> Vector3:
	return Vector3(
		round(pos.x / grid_size) * grid_size,
		ground_y,
		round(pos.z / grid_size) * grid_size
	)


func _is_occupied(pos: Vector3) -> bool:
	# Use physics shape query to detect any existing colliders at the placement position
	var space = get_world_3d().direct_space_state
	var shape = BoxShape3D.new()
	# Approximate size based on typical building dimensions; use a default if data unavailable
	shape.size = Vector3(grid_size * 0.9, 2.0, grid_size * 0.9)
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# Position the shape at the proposed location (centered on Y)
	query.transform = Transform3D(Basis(), pos + Vector3(0, 1.0, 0))
	query.collision_mask = 1
	var results = space.intersect_shape(query)
	if results.size() > 0:
		return true
	# Fallback distance check for existing building nodes
	for b in placed_buildings:
		if b.global_position.distance_to(pos) < grid_size * 0.8:
			return true
	return false


func _highlight_building(building: Node3D, highlight: bool) -> void:
	for child in building.get_children():
		if child is CSGBox3D and child.name == "Body":
			if highlight:
				child.operation = CSGShape3D.OPERATION_UNION
				var mat: StandardMaterial3D = child.material as StandardMaterial3D
				if mat:
					mat.emission_enabled = true
					mat.emission = Color(0.3, 0.6, 1.0)
					mat.emission_energy_multiplier = 0.3
			else:
				var mat: StandardMaterial3D = child.material as StandardMaterial3D
				if mat:
					mat.emission_enabled = false
			break


func _apply_level_visuals(building: Node3D) -> void:
	var level: int = building.get_meta("level", 1)
	for child in building.get_children():
		if child is CSGBox3D and child.name == "Body":
			child.size.y = child.size.y + 0.3 * (level - 1)
			child.position.y = child.position.y + 0.15 * (level - 1)
			break
