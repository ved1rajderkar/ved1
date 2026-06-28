class_name BuildingData
extends RefCounted

## Static data for all building types.

const BUILDINGS: Dictionary = {
	"small_shop": {
		"name": "Small Shop",
		"description": "A basic retail shop.",
		"cost": 500,
		"size": Vector3(4, 3, 4),
		"color": Color(0.8, 0.6, 0.3),
		"income_per_day": 50,
		"upkeep_per_day": 10,
		"workers_required": 2,
		"materials_required": 20,
		"category": "commercial",
	},
	"medium_shop": {
		"name": "Medium Shop",
		"description": "A larger retail space.",
		"cost": 1500,
		"size": Vector3(6, 4, 6),
		"color": Color(0.7, 0.5, 0.2),
		"income_per_day": 150,
		"upkeep_per_day": 25,
		"workers_required": 4,
		"materials_required": 40,
		"category": "commercial",
	},
	"warehouse": {
		"name": "Warehouse",
		"description": "Stores materials and goods.",
		"cost": 1000,
		"size": Vector3(8, 5, 6),
		"color": Color(0.5, 0.5, 0.55),
		"income_per_day": 30,
		"upkeep_per_day": 15,
		"workers_required": 1,
		"materials_required": 50,
		"category": "storage",
	},
	"office": {
		"name": "Office",
		"description": "Increases worker efficiency.",
		"cost": 2000,
		"size": Vector3(6, 5, 6),
		"color": Color(0.3, 0.4, 0.7),
		"income_per_day": 80,
		"upkeep_per_day": 20,
		"workers_required": 3,
		"materials_required": 30,
		"category": "admin",
	},
	"factory": {
		"name": "Factory",
		"description": "Produces materials over time.",
		"cost": 3000,
		"size": Vector3(10, 6, 8),
		"color": Color(0.4, 0.4, 0.4),
		"income_per_day": 200,
		"upkeep_per_day": 50,
		"workers_required": 8,
		"materials_required": 60,
		"category": "production",
	},
	"cafeteria": {
		"name": "Cafeteria",
		"description": "Boosts worker happiness.",
		"cost": 800,
		"size": Vector3(5, 3, 5),
		"color": Color(0.9, 0.7, 0.4),
		"income_per_day": 20,
		"upkeep_per_day": 12,
		"workers_required": 2,
		"materials_required": 15,
		"category": "amenity",
	},
	"park": {
		"name": "Park",
		"description": "Increases nearby happiness.",
		"cost": 400,
		"size": Vector3(6, 1, 6),
		"color": Color(0.2, 0.7, 0.3),
		"income_per_day": 0,
		"upkeep_per_day": 5,
		"workers_required": 0,
		"materials_required": 10,
		"category": "amenity",
	},
	"security_hub": {
		"name": "Security Hub",
		"description": "Prevents random events and theft.",
		"cost": 2500,
		"size": Vector3(5, 4, 5),
		"color": Color(0.2, 0.2, 0.6),
		"income_per_day": 0,
		"upkeep_per_day": 30,
		"workers_required": 3,
		"materials_required": 25,
		"category": "admin",
	},
}


static func get_building(building_type: String) -> Dictionary:
	return BUILDINGS.get(building_type, {})


static func get_all_types() -> Array[String]:
	var types: Array[String] = []
	for key in BUILDINGS:
		types.append(key)
	return types


static func get_by_category(category: String) -> Dictionary:
	var result: Dictionary = {}
	for key in BUILDINGS:
		if BUILDINGS[key].get("category", "") == category:
			result[key] = BUILDINGS[key]
	return result


static func get_categories() -> Array[String]:
	var cats: Dictionary = {}
	for key in BUILDINGS:
		cats[BUILDINGS[key].get("category", "other")] = true
	var result: Array[String] = []
	for c in cats:
		result.append(c)
	return result
