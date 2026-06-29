extends Node3D

signal device_placed(device_name: String, pos: Vector3)
signal device_picked(device_name: String, shelf_idx: int)
signal shelf_restocked(shelf_idx: int, count: int)

const DEVICES_DIR: String = "res://assets/devices"

@export var shelf_positions: Array[Vector3] = [
	Vector3(-5.0, 0.8, -4.5),
	Vector3(-2.5, 0.8, -4.5),
	Vector3(0.0, 0.8, -4.5),
	Vector3(2.5, 0.8, -4.5),
	Vector3(5.0, 0.8, -4.5),
	Vector3(-5.0, 0.8, -1.5),
	Vector3(-2.5, 0.8, -1.5),
]
@export var max_per_shelf: int = 3
@export var device_scale_min: float = 0.5
@export var device_scale_max: float = 1.0

var shelf_devices: Array[Array] = []
var _device_scenes: Array[PackedScene] = []
var _device_names: Array[String] = []


func _ready() -> void:
	_scan_devices()
	_init_shelves()
	_stock_all()


func _scan_devices() -> void:
	_device_scenes.clear()
	_device_names.clear()
	_scan_recursive(DEVICES_DIR)
	if _device_scenes.is_empty():
		push_warning("StoreManager: No device models found in " + DEVICES_DIR)


func _scan_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			if fname != "." and fname != "..":
				_scan_recursive(path + "/" + fname)
		else:
			if fname.ends_with(".glb") or fname.ends_with(".gltf"):
				var res: Resource = load(path + "/" + fname)
				if res is PackedScene:
					_device_scenes.append(res)
					_device_names.append(fname.get_basename())
		fname = dir.get_next()
	dir.list_dir_end()


func _init_shelves() -> void:
	shelf_devices.clear()
	for i in range(shelf_positions.size()):
		shelf_devices.append([])


func _stock_all() -> void:
	if _device_scenes.is_empty():
		return
	for idx in range(shelf_positions.size()):
		_fill_shelf(idx)


func _fill_shelf(shelf_idx: int) -> void:
	if shelf_idx < 0 or shelf_idx >= shelf_devices.size():
		return
	var devices: Array = shelf_devices[shelf_idx]
	var shelf_pos: Vector3 = shelf_positions[shelf_idx]
	while devices.size() < max_per_shelf:
		var dev_idx: int = (shelf_idx * max_per_shelf + devices.size()) % _device_scenes.size()
		var scene: PackedScene = _device_scenes[dev_idx]
		var dname: String = _device_names[dev_idx]
		var inst: Node3D = scene.instantiate() as Node3D
		if inst == null:
			continue
		var slot: int = devices.size()
		var offset: Vector3 = Vector3((slot - 1) * 1.0, 0.0, randf_range(-0.2, 0.2))
		inst.position = shelf_pos + offset
		inst.rotation.y = randf() * TAU
		var sc: float = randf_range(device_scale_min, device_scale_max)
		inst.scale = Vector3(sc, sc, sc)
		inst.name = dname
		add_child(inst)
		_make_pickable(inst, dname, shelf_idx)
		devices.append(inst)
		device_placed.emit(dname, inst.position)


func _make_pickable(node: Node3D, device_name: String, shelf_idx: int) -> void:
	var area: Area3D = Area3D.new()
	area.name = "PickableArea"
	area.collision_layer = 4
	area.collision_mask = 1
	area.set_meta("device_name", device_name)
	area.set_meta("shelf_idx", shelf_idx)
	area.set_meta("is_pickable", true)
	node.add_child(area)

	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	col.shape = box
	area.add_child(col)


func pick_device(shelf_idx: int, slot_idx: int) -> Node3D:
	if shelf_idx < 0 or shelf_idx >= shelf_devices.size():
		return null
	var devices: Array = shelf_devices[shelf_idx]
	if slot_idx < 0 or slot_idx >= devices.size():
		return null
	var dev: Node3D = devices[slot_idx] as Node3D
	if dev == null:
		return null
	var dname: String = dev.name
	devices.remove_at(slot_idx)
	if dev.get_parent() != null:
		dev.get_parent().remove_child(dev)
	device_picked.emit(dname, shelf_idx)
	return dev


func restock_shelf(shelf_idx: int) -> int:
	if shelf_idx < 0 or shelf_idx >= shelf_devices.size():
		return 0
	var devices: Array = shelf_devices[shelf_idx]
	var before: int = devices.size()
	_fill_shelf(shelf_idx)
	var added: int = devices.size() - before
	shelf_restocked.emit(shelf_idx, devices.size())
	return added


func get_available_shelf() -> int:
	for i in range(shelf_devices.size()):
		if (shelf_devices[i] as Array).size() < max_per_shelf:
			return i
	return -1


func get_total_devices() -> int:
	var total: int = 0
	for d in shelf_devices:
		total += (d as Array).size()
	return total


func get_shelf_count() -> int:
	return shelf_devices.size()


func get_devices_on_shelf(shelf_idx: int) -> Array:
	if shelf_idx < 0 or shelf_idx >= shelf_devices.size():
		return []
	return shelf_devices[shelf_idx]
