extends Node3D

## Manages all placed buildings: placement, upgrades, removal.

signal building_placed(building: Node3D)
signal building_removed(building: Node3D)
signal building_upgraded(building: Node3D, new_level: int)
signal placement_preview(building_type: String)
signal placement_cancelled

var placed_buildings: Array[Node3D] = []
var selected_building: Node3D = null
var preview_building: Node3D = null
var is_placing: bool = false

var grid_size: float = 4.0
var ground_level: float = 0.0

@onready var economy: Node = %EconomyManager


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return

	if event is InputEventMouseMotion:
		_update_preview_position()

	if event.is_action_pressed("ui_accept"):
		_confirm_placement()

	if event.is_action_pressed("ui_cancel"):
		_cancel_placement()


func start_placement(building_type: String) -> void:
	var data: Dictionary = BuildingData.get_building(building_type)
	if data.is_empty():
		return

	if not economy.can_afford(data.get("cost", 0)):
		return

	is_placing = true
	preview_building = _create_building_preview(building_type)
	if preview_building:
		placement_preview.emit(building_type)


func _cancel_placement() -> void:
	is_placing = false
	if preview_building:
		preview_building.queue_free()
		preview_building = null
	placement_cancelled.emit()


func _confirm_placement() -> void:
	if not preview_building:
		return

	var grid_pos: Vector3 = _snap_to_grid(preview_building.global_position)
	var building_type: String = preview_building.get_meta("building_type", "")
	var data: Dictionary = BuildingData.get_building(building_type)

	if _is_position_occupied(grid_pos):
		return

	if not economy.spend_money(data.get("cost", 0)):
		return

	var building: Node3D = _create_building(building_type, grid_pos)
	placed_buildings.append(building)
	_add_building_costs_to_economy(building)

	# Clean up preview
	preview_building.queue_free()
	preview_building = null
	is_placing = false

	building_placed.emit(building)


func remove_building(building: Node3D) -> void:
	if building not in placed_buildings:
		return

	var data: Dictionary = BuildingData.get_building(building.get_meta("building_type", ""))
	var refund: int = int(data.get("cost", 0) * 0.5)
	economy.add_money(refund)

	_remove_building_costs_from_economy(building)
	placed_buildings.erase(building)
	building.queue_free()
	building_removed.emit(building)


func upgrade_building(building: Node3D) -> bool:
	var current_level: int = building.get_meta("level", 1)
	if current_level >= 5:
		return false

	var building_type: String = building.get_meta("building_type", "")
	var data: Dictionary = BuildingData.get_building(building_type)
	var upgrade_cost: int = int(data.get("cost", 0) * current_level * 0.75)

	if not economy.spend_money(upgrade_cost):
		return false

	_remove_building_costs_from_economy(building)
	building.set_meta("level", current_level + 1)
	_apply_upgrade_visuals(building)
	_add_building_costs_to_economy(building)

	building_upgraded.emit(building, current_level + 1)
	return true


func select_building(building: Node3D) -> void:
	if selected_building:
		deselect_building()
	selected_building = building
	if building.has_method("show_info"):
		building.show_info()


func deselect_building() -> void:
	if selected_building and selected_building.has_method("hide_info"):
		selected_building.hide_info()
	selected_building = null


func clear_all() -> void:
	for building in placed_buildings:
		building.queue_free()
	placed_buildings.clear()
	selected_building = null


func get_all_buildings() -> Array[Node3D]:
	return placed_buildings


func get_building_count(building_type: String) -> int:
	var count: int = 0
	for b in placed_buildings:
		if b.get_meta("building_type", "") == building_type:
			count += 1
	return count


func _create_building(building_type: String, position: Vector3) -> Node3D:
	var data: Dictionary = BuildingData.get_building(building_type)
	var building: Node3D = Node3D.new()
	building.name = data.get("name", "Building")
	building.position = position
	building.set_meta("building_type", building_type)
	building.set_meta("level", 1)

	# Visual: simple colored box
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = data.get("size", Vector3(4, 3, 4))
	mesh_instance.mesh = box

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = data.get("color", Color(0.6, 0.6, 0.6))
	mesh_instance.set_surface_override_material(0, material)
	building.add_child(mesh_instance)

	# Collision
	var static_body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = data.get("size", Vector3(4, 3, 4))
	collision.shape = shape
	static_body.add_child(collision)
	building.add_child(static_body)

	add_child(building)
	return building


func _create_building_preview(building_type: String) -> Node3D:
	var data: Dictionary = BuildingData.get_building(building_type)
	var preview: Node3D = Node3D.new()
	preview.set_meta("building_type", building_type)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = data.get("size", Vector3(4, 3, 4))
	mesh_instance.mesh = box

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.8, 0.3, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.set_surface_override_material(0, material)
	preview.add_child(mesh_instance)

	add_child(preview)
	return preview


func _update_preview_position() -> void:
	if not preview_building:
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_origin, ray_origin + ray_dir * 1000.0
	)
	var result: Dictionary = space_state.intersect_ray(query)

	if result:
		preview_building.global_position = _snap_to_grid(result.position)


func _snap_to_grid(pos: Vector3) -> Vector3:
	return Vector3(
		round(pos.x / grid_size) * grid_size,
		ground_level,
		round(pos.z / grid_size) * grid_size
	)


func _is_position_occupied(pos: Vector3) -> bool:
	for b in placed_buildings:
		if b.global_position.distance_to(pos) < grid_size * 0.5:
			return true
	return false


func _apply_upgrade_visuals(building: Node3D) -> void:
	var level: int = building.get_meta("level", 1)
	var mesh: MeshInstance3D = building.get_child(0) as MeshInstance3D
	if mesh and mesh.mesh is BoxMesh:
		var box: BoxMesh = mesh.mesh as BoxMesh
		box.size.y = box.size.y + 0.5


func _add_building_costs_to_economy(building: Node3D) -> void:
	var data: Dictionary = BuildingData.get_building(building.get_meta("building_type", ""))
	var workers: int = data.get("workers_required", 0)
	var materials: int = data.get("materials_required", 0)
	if workers > 0:
		economy.spend_resource("workers", workers)
	if materials > 0:
		economy.spend_resource("materials", materials)


func _remove_building_costs_from_economy(building: Node3D) -> void:
	var data: Dictionary = BuildingData.get_building(building.get_meta("building_type", ""))
	var workers: int = data.get("workers_required", 0)
	var materials: int = data.get("materials_required", 0)
	if workers > 0:
		economy.add_resource("workers", workers)
	if materials > 0:
		economy.add_resource("materials", materials)
