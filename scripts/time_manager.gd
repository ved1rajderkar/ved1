extends Node

## Manages game time, day/night cycle, and game speed.

signal day_started(day: int)
signal hour_changed(hour: int)
signal speed_changed(speed: float)

const HOURS_PER_DAY: int = 24
const SECONDS_PER_GAME_MINUTE: float = 0.5

var current_day: int = 1
var current_hour: int = 6
var current_minute: int = 0
var time_accumulator: float = 0.0
var game_speed: float = 1.0
var is_paused: bool = false
var paused_by_player: bool = false

var day_start_hour: int = 6
var night_start_hour: int = 22


func _process(delta: float) -> void:
	if is_paused:
		return

	time_accumulator += delta * game_speed

	var minutes_to_advance: int = int(time_accumulator / SECONDS_PER_GAME_MINUTE)
	if minutes_to_advance > 0:
		time_accumulator -= minutes_to_advance * SECONDS_PER_GAME_MINUTE
		_advance_time(minutes_to_advance)


func _advance_time(minutes: int) -> void:
	current_minute += minutes

	while current_minute >= 60:
		current_minute -= 60
		current_hour += 1
		hour_changed.emit(current_hour)

		if current_hour >= HOURS_PER_DAY:
			current_hour = 0
			current_day += 1
			day_started.emit(current_day)


func set_speed(speed: float) -> void:
	game_speed = clampf(speed, 0.0, 4.0)
	speed_changed.emit(game_speed)


func toggle_pause() -> void:
	is_paused = !is_paused


func set_paused(paused: bool) -> void:
	is_paused = paused


func is_daytime() -> bool:
	return current_hour >= day_start_hour and current_hour < night_start_hour


func is_nighttime() -> bool:
	return !is_daytime()


func get_time_of_day() -> String:
	if current_hour < 6:
		return "night"
	elif current_hour < 12:
		return "morning"
	elif current_hour < 18:
		return "afternoon"
	else:
		return "evening"


func get_day_progress() -> float:
	return float(current_hour * 60 + current_minute) / float(HOURS_PER_DAY * 60)


func get_formatted_time() -> String:
	return "%02d:%02d" % [current_hour, current_minute]


func get_day_name() -> String:
	var day_names: Array[String] = [
		"Monday", "Tuesday", "Wednesday", "Thursday",
		"Friday", "Saturday", "Sunday"
	]
	return day_names[(current_day - 1) % 7]


func get_stats() -> Dictionary:
	return {
		"day": current_day,
		"hour": current_hour,
		"minute": current_minute,
		"speed": game_speed,
		"day_name": get_day_name(),
		"time_of_day": get_time_of_day(),
	}
