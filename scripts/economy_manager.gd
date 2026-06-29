extends Node

signal money_changed(new_amount: int)
signal income_changed(amount: int)
signal expense_changed(amount: int)
signal resource_changed(resource: String, new_amount: int)
signal went_bankrupt

var money: int = 5000
var daily_income: int = 0
var daily_upkeep: int = 0
var total_earned: int = 0
var total_spent: int = 0
var lifetime_days: int = 0

var workers: int = 10
var materials: int = 100
var happiness: int = 80
var reputation: int = 50

const MAX_WORKERS: int = 100
const MAX_MATERIALS: int = 1000
const MAX_HAPPINESS: int = 100
const MAX_REPUTATION: int = 100


func reset() -> void:
	money = 5000
	daily_income = 0
	daily_upkeep = 0
	total_earned = 0
	total_spent = 0
	lifetime_days = 0
	workers = 10
	materials = 100
	happiness = 80
	reputation = 50
	recalculate_totals()
	money_changed.emit(money)


func add_money(amount: int) -> bool:
	if amount <= 0:
		return false
	money += amount
	total_earned += amount
	money_changed.emit(money)
	return true


func spend_money(amount: int) -> bool:
	if amount <= 0 or money < amount:
		return false
	money -= amount
	total_spent += amount
	money_changed.emit(money)
	return true


func can_afford(amount: int) -> bool:
	return money >= amount


func add_workers(count: int) -> void:
	workers = mini(workers + count, MAX_WORKERS)
	resource_changed.emit("workers", workers)


func remove_workers(count: int) -> bool:
	if workers < count:
		return false
	workers -= count
	resource_changed.emit("workers", workers)
	return true


func add_materials(count: int) -> void:
	materials = mini(materials + count, MAX_MATERIALS)
	resource_changed.emit("materials", materials)


func remove_materials(count: int) -> bool:
	if materials < count:
		return false
	materials -= count
	resource_changed.emit("materials", materials)
	return true


func add_happiness(amount: int) -> void:
	happiness = clampi(happiness + amount, 0, MAX_HAPPINESS)
	resource_changed.emit("happiness", happiness)


func add_reputation(amount: int) -> void:
	reputation = clampi(reputation + amount, 0, MAX_REPUTATION)
	resource_changed.emit("reputation", reputation)


func process_daily() -> void:
	lifetime_days += 1
	recalculate_totals()
	var profit: int = daily_income - daily_upkeep
	if profit >= 0:
		add_money(profit)
	else:
		spend_money(absi(profit))
	happiness = clampi(happiness + (1 if profit > 0 else -2), 0, MAX_HAPPINESS)
	resource_changed.emit("happiness", happiness)
	materials = clampi(materials - (_get_bs().get_building_count() * 2), 0, MAX_MATERIALS)
	resource_changed.emit("materials", materials)
	if money < 0:
		went_bankrupt.emit()


func _get_bs() -> Node3D:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.get_node_or_null("Main/BuildingSystem")
	return null


func recalculate_totals() -> void:
	daily_income = 0
	daily_upkeep = 0
	var bs: Node3D = _get_bs()
	if not bs:
		return
	for b in bs.get_all_buildings():
		var btype: String = b.get_meta("building_type", "")
		var data: Dictionary = BuildingData.get_building(btype)
		if data.is_empty():
			continue
		var level: int = b.get_meta("level", 1)
		daily_income += int(data.get("income", 0) * level * (1.0 + reputation * 0.01))
		daily_upkeep += int(data.get("upkeep", 0) * level)
	income_changed.emit(daily_income)
	expense_changed.emit(daily_upkeep)


func get_profit() -> int:
	return daily_income - daily_upkeep


func get_stats() -> Dictionary:
	return {
		"money": money,
		"daily_income": daily_income,
		"daily_upkeep": daily_upkeep,
		"profit": get_profit(),
		"workers": workers,
		"materials": materials,
		"happiness": happiness,
		"reputation": reputation,
		"total_earned": total_earned,
		"total_spent": total_spent,
	}
