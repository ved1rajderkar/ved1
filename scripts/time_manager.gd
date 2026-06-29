extends Node

signal hour_changed(hour: int)
signal day_started(day: int)
signal speed_changed(new_speed: float)
signal period_changed(period: String)

const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const SECONDS_PER_GAME_MINUTE: float = 0.5

var current_hour: int = 6
var current_minute: int = 0
var game_speed: float = 1.0
var paused: bool = false
var accumulator: float = 0.0

var day_start_hour: int = 6
var night_hour: int = 22


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if paused or GameManager.state != GameManager.State.PLAYING:
		return

	accumulator += delta * game_speed
	var minutes_to_add: int = int(accumulator / SECONDS_PER_GAME_MINUTE)
	if minutes_to_add <= 0:
		return
	accumulator -= minutes_to_add * SECONDS_PER_GAME_MINUTE
	_tick(minutes_to_add)


func _tick(minutes: int) -> void:
	current_minute += minutes
	while current_minute >= MINUTES_PER_HOUR:
		current_minute -= MINUTES_PER_HOUR
		current_hour += 1
		hour_changed.emit(current_hour)
		_check_period()
		if current_hour >= HOURS_PER_DAY:
			current_hour = 0
			day_started.emit(GameManager.current_day)
			GameManager.advance_day()


func _check_period() -> void:
	var p: String = get_time_period()
	period_changed.emit(p)


func reset() -> void:
	current_hour = 6
	current_minute = 0
	accumulator = 0.0
	paused = false
	game_speed = 1.0


func set_speed(speed: float) -> void:
	game_speed = clampf(speed, 0.0, 4.0)
	speed_changed.emit(game_speed)


func set_paused(value: bool) -> void:
	paused = value


func is_daytime() -> bool:
	return current_hour >= day_start_hour and current_hour < night_hour


func get_time_period() -> String:
	if current_hour < 6:
		return "night"
	elif current_hour < 12:
		return "morning"
	elif current_hour < 18:
		return "afternoon"
	else:
		return "evening"


func get_day_progress() -> float:
	return float(current_hour * MINUTES_PER_HOUR + current_minute) / float(HOURS_PER_DAY * MINUTES_PER_HOUR)


func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]


func get_day_name() -> String:
	var names: Array[String] = [
		"Monday", "Tuesday", "Wednesday", "Thursday",
		"Friday", "Saturday", "Sunday"
	]
	return names[(GameManager.current_day - 1) % 7]


func get_speed_label() -> String:
	if game_speed == 0.0:
		return "Paused"
	return "%.0fx" % game_speed


func get_stats() -> Dictionary:
	return {
		"hour": current_hour,
		"minute": current_minute,
		"speed": game_speed,
		"day_name": get_day_name(),
		"period": get_time_period(),
		"time_string": get_time_string(),
	}
