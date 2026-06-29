class_name BuildingData
extends RefCounted

const BUILDINGS: Dictionary = {
	"display_shelf": {
		"name": "Display Shelf",
		"description": "Holds phones for customers to browse.",
		"cost": 300,
		"upgrade_cost_mult": 1.5,
		"size": Vector3(2.0, 1.5, 0.8),
		"floor_size": Vector3(2.2, 0.1, 1.0),
		"color": Color(0.55, 0.4, 0.25),
		"floor_color": Color(0.45, 0.32, 0.2),
		"income": 40,
		"upkeep": 5,
		"workers": 1,
		"materials": 10,
		"category": "retail",
		"max_level": 5,
	},
	"premium_shelf": {
		"name": "Premium Display",
		"description": "High-end phone display, attracts wealthy customers.",
		"cost": 800,
		"upgrade_cost_mult": 1.8,
		"size": Vector3(2.5, 2.0, 1.0),
		"floor_size": Vector3(2.7, 0.1, 1.2),
		"color": Color(0.2, 0.2, 0.25),
		"floor_color": Color(0.15, 0.15, 0.18),
		"income": 120,
		"upkeep": 15,
		"workers": 2,
		"materials": 25,
		"category": "retail",
		"max_level": 5,
	},
	"cash_register": {
		"name": "Cash Register",
		"description": "Processes sales. Required for income.",
		"cost": 500,
		"upgrade_cost_mult": 1.6,
		"size": Vector3(1.5, 1.2, 0.8),
		"floor_size": Vector3(1.7, 0.1, 1.0),
		"color": Color(0.3, 0.3, 0.35),
		"floor_color": Color(0.25, 0.25, 0.28),
		"income": 0,
		"upkeep": 10,
		"workers": 1,
		"materials": 15,
		"category": "counter",
		"max_level": 3,
		"required": true,
	},
	"repair_bench": {
		"name": "Repair Bench",
		"description": "Repairs phones, generates bonus income.",
		"cost": 600,
		"upgrade_cost_mult": 1.5,
		"size": Vector3(2.0, 1.0, 1.0),
		"floor_size": Vector3(2.2, 0.1, 1.2),
		"color": Color(0.4, 0.5, 0.45),
		"floor_color": Color(0.32, 0.4, 0.35),
		"income": 60,
		"upkeep": 8,
		"workers": 2,
		"materials": 20,
		"category": "service",
		"max_level": 4,
	},
	"storage_room": {
		"name": "Storage Room",
		"description": "Stores extra inventory and materials.",
		"cost": 400,
		"upgrade_cost_mult": 1.4,
		"size": Vector3(3.0, 2.5, 3.0),
		"floor_size": Vector3(3.2, 0.1, 3.2),
		"color": Color(0.5, 0.48, 0.45),
		"floor_color": Color(0.4, 0.38, 0.35),
		"income": 0,
		"upkeep": 5,
		"workers": 0,
		"materials": 30,
		"category": "storage",
		"max_level": 3,
	},
	"break_room": {
		"name": "Break Room",
		"description": "Workers rest here. Boosts happiness.",
		"cost": 350,
		"upgrade_cost_mult": 1.3,
		"size": Vector3(3.0, 2.5, 3.0),
		"floor_size": Vector3(3.2, 0.1, 3.2),
		"color": Color(0.7, 0.6, 0.4),
		"floor_color": Color(0.6, 0.5, 0.32),
		"income": 0,
		"upkeep": 8,
		"workers": 0,
		"materials": 15,
		"category": "amenity",
		"max_level": 3,
	},
	"ad_sign": {
		"name": "Advertising Sign",
		"description": "Attracts more customers. Boosts reputation.",
		"cost": 250,
		"upgrade_cost_mult": 1.4,
		"size": Vector3(1.0, 2.5, 0.3),
		"floor_size": Vector3(1.2, 0.1, 0.5),
		"color": Color(0.8, 0.2, 0.2),
		"floor_color": Color(0.6, 0.15, 0.15),
		"income": 10,
		"upkeep": 3,
		"workers": 0,
		"materials": 5,
		"category": "marketing",
		"max_level": 4,
	},
	"security_cam": {
		"name": "Security Camera",
		"description": "Prevents theft. Reduces losses.",
		"cost": 450,
		"upgrade_cost_mult": 1.5,
		"size": Vector3(0.4, 0.4, 0.4),
		"floor_size": Vector3(0.6, 0.1, 0.6),
		"color": Color(0.15, 0.15, 0.2),
		"floor_color": Color(0.1, 0.1, 0.12),
		"income": 0,
		"upkeep": 6,
		"workers": 0,
		"materials": 8,
		"category": "security",
		"max_level": 3,
	},
}


static func get_building(building_type: String) -> Dictionary:
	return BUILDINGS.get(building_type, {})


static func get_all_types() -> Array[String]:
	var types: Array[String] = []
	for key in BUILDINGS:
		types.append(key)
	return types


static func get_types_by_category(category: String) -> Array[String]:
	var types: Array[String] = []
	for key in BUILDINGS:
		if BUILDINGS[key].get("category", "") == category:
			types.append(key)
	return types


static func get_categories() -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for key in BUILDINGS:
		var cat: String = BUILDINGS[key].get("category", "other")
		if not seen.has(cat):
			seen[cat] = true
			result.append(cat)
	return result


static func get_upgrade_cost(building_type: String, current_level: int) -> int:
	var data: Dictionary = get_building(building_type)
	if data.is_empty():
		return 999999
	var base: int = data.get("cost", 0)
	var mult: float = data.get("upgrade_cost_mult", 1.5)
	return int(base * pow(mult, current_level - 1))


static func get_max_level(building_type: String) -> int:
	return get_building(building_type).get("max_level", 5)
