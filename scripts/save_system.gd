extends Node

const SAVE_PATH: String = "user://savegame.json"

signal saved
signal loaded
signal save_failed
signal load_failed


func save_game() -> bool:
	var data: Dictionary = _build_save_data()
	var json: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		save_failed.emit()
		return false
	file.store_string(json)
	file.close()
	saved.emit()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		load_failed.emit()
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		load_failed.emit()
		return false
	var json_text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(json_text) != OK:
		load_failed.emit()
		return false
	var data: Variant = parser.data
	if not data is Dictionary:
		load_failed.emit()
		return false
	_apply_save_data(data as Dictionary)
	loaded.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _build_save_data() -> Dictionary:
	return {
		"version": 1,
		"company_name": GameManager.company_name,
		"current_day": GameManager.current_day,
		"play_time": GameManager.play_time,
		"economy": {
			"money": Economy.money,
			"total_earned": Economy.total_earned,
			"total_spent": Economy.total_spent,
			"workers": Economy.workers,
			"materials": Economy.materials,
			"happiness": Economy.happiness,
			"reputation": Economy.reputation,
		},
		"time": {
			"hour": TimeManager.current_hour,
			"minute": TimeManager.current_minute,
			"speed": TimeManager.game_speed,
		},
		"buildings": _serialize_buildings(),
	}


func _get_bs() -> Node3D:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.get_node_or_null("Main/BuildingSystem")
	return null


func _apply_save_data(data: Dictionary) -> void:
	GameManager.company_name = data.get("company_name", "PhoneWorld")
	GameManager.current_day = data.get("current_day", 1)
	GameManager.play_time = data.get("play_time", 0.0)

	var econ: Dictionary = data.get("economy", {})
	Economy.money = econ.get("money", 5000)
	Economy.total_earned = econ.get("total_earned", 0)
	Economy.total_spent = econ.get("total_spent", 0)
	Economy.workers = econ.get("workers", 10)
	Economy.materials = econ.get("materials", 100)
	Economy.happiness = econ.get("happiness", 80)
	Economy.reputation = econ.get("reputation", 50)

	var tmr: Dictionary = data.get("time", {})
	TimeManager.current_hour = tmr.get("hour", 6)
	TimeManager.current_minute = tmr.get("minute", 0)
	TimeManager.game_speed = tmr.get("speed", 1.0)

	var bs: Node3D = _get_bs()
	if not bs:
		return
	bs.clear_all()
	var bdata: Array = data.get("buildings", [])
	for bentry: Dictionary in bdata:
		var btype: String = bentry.get("type", "")
		var pos_data: Dictionary = bentry.get("position", {})
		var pos: Vector3 = Vector3(
			pos_data.get("x", 0.0),
			pos_data.get("y", 0.05),
			pos_data.get("z", 0.0)
		)
		var building: Node3D = bs._create_building(btype, pos)
		var level: int = bentry.get("level", 1)
		building.set_meta("level", level)
		bs.placed_buildings.append(building)

	Economy.recalculate_totals()
	Economy.money_changed.emit(Economy.money)


func _serialize_buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var bs: Node3D = _get_bs()
	if not bs:
		return result
	for b: Node3D in bs.get_all_buildings():
		result.append({
			"type": b.get_meta("building_type", ""),
			"level": b.get_meta("level", 1),
			"position": {
				"x": b.global_position.x,
				"y": b.global_position.y,
				"z": b.global_position.z,
			},
		})
	return result
