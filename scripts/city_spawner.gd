extends Node3D

signal city_built(total_buildings: int)

const CITY_MATERIAL_DIR: String = "res://assets/city material"
const EXCLUDED_KEYWORDS: PackedStringArray = ["detail", "parasol", "awning", "overhang"]

@export var city_radius: float = 80.0
@export var city_edge_buffer: float = 25.0
@export var building_count: int = 40
@export var grid_size: float = 16.0
@export var build_offset: Vector3 = Vector3.ZERO

var buildings: Array[Node3D] = []
var _building_meshes: Array[Mesh] = []


func _ready() -> void:
	_scan_city_meshes()
	_spawn_buildings()
	city_built.emit(buildings.size())


func _scan_city_meshes() -> void:
	_building_meshes.clear()
	_scan_dir(CITY_MATERIAL_DIR)
	if _building_meshes.is_empty():
		push_warning("CitySpawner: No .glb files found in " + CITY_MATERIAL_DIR)


func _scan_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			if fname != "." and fname != "..":
				_scan_dir(path + "/" + fname)
		else:
			if fname.ends_with(".glb") or fname.ends_with(".gltf"):
				var skip: bool = false
				for kw in EXCLUDED_KEYWORDS:
					if kw in fname.to_lower():
						skip = true
						break
				if not skip:
					var res: Resource = load(path + "/" + fname)
					if res is Mesh:
						_building_meshes.append(res)
					elif res is PackedScene:
						var inst: Node = res.instantiate()
						for child in inst.get_children():
							if child is MeshInstance3D and child.mesh != null:
								_building_meshes.append(child.mesh)
						inst.queue_free()
		fname = dir.get_next()
	dir.list_dir_end()


func _spawn_buildings() -> void:
	if _building_meshes.is_empty():
		return
	var half: int = int(city_radius / grid_size)
	for i in range(building_count):
		var mesh: Mesh = _building_meshes[i % _building_meshes.size()]
		var pos: Vector3 = _city_position(i, half) + build_offset
		pos.y = 0.0
		_spawn_single_building(mesh, pos)


func _city_position(index: int, half: int) -> Vector3:
	var side: int = index % 4
	var ring: int = (index / 4) + 2
	var offset: int = index % 6 - 3
	match side:
		0: return Vector3(float(offset) * grid_size, 0, float(ring) * grid_size)
		1: return Vector3(float(ring) * grid_size, 0, float(offset) * grid_size)
		2: return Vector3(float(-offset) * grid_size, 0, float(-ring) * grid_size)
		3: return Vector3(float(-ring) * grid_size, 0, float(-offset) * grid_size)
	return Vector3.ZERO


func _spawn_single_building(mesh: Mesh, pos: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Building_" + str(buildings.size())
	body.position = pos
	body.rotation.y = randf() * TAU
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.mesh = mesh
	var s: float = randf_range(0.8, 1.4)
	mesh_inst.scale = Vector3(s, s, s)
	var dist: float = Vector2(pos.x, pos.z).length()
	if dist < city_edge_buffer:
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	var aabb: AABB = mesh.get_aabb()
	box.size = aabb.size * s
	col.shape = box
	col.position = Vector3(0, aabb.size.y * s * 0.5, 0)
	body.add_child(col)

	buildings.append(body)


func get_random_building_pos() -> Vector3:
	if buildings.is_empty():
		return Vector3.ZERO
	return buildings[randi() % buildings.size()].position


func get_building_at(idx: int) -> Node3D:
	if idx < 0 or idx >= buildings.size():
		return null
	return buildings[idx]
