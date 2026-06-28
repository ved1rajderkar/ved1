extends Node

## Handles saving and loading game state to disk.

const SAVE_PATH: String = "user://savegame.json"

signal game_saved
signal game_loaded


func save_game(data: Dictionary) -> bool:
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(json_string)
	file.close()
	game_saved.emit()
	return true


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		return {}

	game_loaded.emit()
	return json.data as Dictionary


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func build_save_data(
	game: Node, economy: Node, time: Node, buildings: Node
) -> Dictionary:
	return {
		"version": 1,
		"company_name": game.company_name,
		"total_play_time": game.total_play_time,
		"economy": economy.get_stats(),
		"time": time.get_stats(),
		"buildings": _serialize_buildings(buildings.get_all_buildings()),
	}


func apply_save_data(data: Dictionary, game: Node, economy: Node, time: Node, buildings: Node) -> void:
	if data.is_empty():
		return

	game.company_name = data.get("company_name", game.company_name)
	game.total_play_time = data.get("total_play_time", 0.0)

	var econ_data: Dictionary = data.get("economy", {})
	economy.money = econ_data.get("money", 5000)
	economy.total_earned = econ_data.get("total_earned", 0)
	economy.total_spent = econ_data.get("total_spent", 0)
	economy.resources = econ_data.get("resources", economy.resources)

	var time_data: Dictionary = data.get("time", {})
	time.current_day = time_data.get("day", 1)
	time.current_hour = time_data.get("hour", 6)
	time.current_minute = time_data.get("minute", 0)
	time.game_speed = time_data.get("speed", 1.0)


func _serialize_buildings(buildings: Array[Node3D]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for b in buildings:
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
