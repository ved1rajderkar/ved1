extends Node

## Manages all financial aspects: money, income, expenses, resources.

signal money_changed(new_amount: int)
signal income_changed(amount: int)
signal expense_changed(amount: int)
signal resource_changed(resource: String, amount: int)

var money: int = 5000
var daily_income: int = 0
var daily_expenses: int = 0
var total_earned: int = 0
var total_spent: int = 0

var resources: Dictionary = {
	"materials": 100,
	"workers": 10,
	"happiness": 80,
}


func reset() -> void:
	money = 5000
	daily_income = 0
	daily_expenses = 0
	total_earned = 0
	total_spent = 0
	resources = {
		"materials": 100,
		"workers": 10,
		"happiness": 80,
	}


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


func add_resource(resource: String, amount: int) -> void:
	if resource in resources:
		resources[resource] += amount
		resource_changed.emit(resource, resources[resource])


func spend_resource(resource: String, amount: int) -> bool:
	if resource not in resources or resources[resource] < amount:
		return false
	resources[resource] -= amount
	resource_changed.emit(resource, resources[resource])
	return true


func has_resource(resource: String, amount: int) -> bool:
	return resource in resources and resources[resource] >= amount


func recalculate_income(buildings: Array) -> void:
	daily_income = 0
	for b in buildings:
		if b.has_method("get_income"):
			daily_income += b.get_income()
	income_changed.emit(daily_income)


func recalculate_expenses(buildings: Array) -> void:
	daily_expenses = 0
	for b in buildings:
		if b.has_method("get_upkeep"):
			daily_expenses += b.get_upkeep()
	expense_changed.emit(daily_expenses)


func process_daily_income() -> void:
	add_money(daily_income)


func process_daily_expenses() -> void:
	spend_money(daily_expenses)


func get_profit() -> int:
	return daily_income - daily_expenses


func get_stats() -> Dictionary:
	return {
		"money": money,
		"daily_income": daily_income,
		"daily_expenses": daily_expenses,
		"total_earned": total_earned,
		"total_spent": total_spent,
		"resources": resources.duplicate(),
	}
