extends Node

signal game_started
signal game_paused
signal game_resumed
signal game_restarted
signal game_over(reason: String)
signal day_advanced(day: int)

enum State { MENU, PLAYING, PAUSED, GAME_OVER }

var state: State = State.MENU
var current_day: int = 1
var company_name: String = "PhoneWorld"
var play_time: float = 0.0
var total_days_played: int = 0
var high_score: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_high_score()


func _process(delta: float) -> void:
	if state == State.PLAYING:
		play_time += delta


func _get_ui():
	var ui = Engine.get_meta("UIManager", null)
	if ui:
		return ui
	var tree = get_tree()
	if tree:
		return tree.root.get_node_or_null("Main/UIManager")
	return null


func _get_building_system() -> Node3D:
	return get_tree().root.get_node_or_null("Main/BuildingSystem")


func start_game() -> void:
	current_day = 1
	play_time = 0.0
	total_days_played = 0
	state = State.PLAYING
	get_tree().paused = false
	Economy.reset()
	TimeManager.reset()
	var bs: Node3D = _get_building_system()
	if bs:
		bs.clear_all()
	game_started.emit()
	var ui: CanvasLayer = _get_ui()
	if ui:
		ui.show_hud()


func pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	get_tree().paused = true
	var ui: CanvasLayer = _get_ui()
	if ui:
		ui.show_pause()
	game_paused.emit()


func resume_game() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	var ui: CanvasLayer = _get_ui()
	if ui:
		ui.hide_pause()
	game_resumed.emit()


func restart_game() -> void:
	get_tree().paused = false
	start_game()
	game_restarted.emit()


func end_game(reason: String) -> void:
	state = State.GAME_OVER
	get_tree().paused = true
	if Economy.money > high_score:
		high_score = Economy.money
		save_high_score()
	var ui: CanvasLayer = _get_ui()
	if ui:
		ui.show_game_over(reason)
	game_over.emit(reason)


func advance_day() -> void:
	current_day += 1
	total_days_played += 1
	Economy.process_daily()
	day_advanced.emit(current_day)
	if Economy.money < -500:
		end_game("Bankrupt! You ran out of money.")


func toggle_pause() -> void:
	match state:
		State.PLAYING:
			pause_game()
		State.PAUSED:
			resume_game()


func set_speed(speed: float) -> void:
	TimeManager.set_speed(speed)


func save_high_score() -> void:
	var config = ConfigFile.new()
	config.set_value("stats", "high_score", high_score)
	config.save("user://highscore.cfg")


func load_high_score() -> void:
	var config = ConfigFile.new()
	if config.load("user://highscore.cfg") == OK:
		high_score = config.get_value("stats", "high_score", 0)


func get_time_string() -> String:
	return TimeManager.get_time_string()


func get_day_string() -> String:
	return "Day %d - %s" % [current_day, TimeManager.get_day_name()]
