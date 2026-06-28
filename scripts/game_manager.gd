extends Node

## Core game manager - handles game state, initialization, and main loop.

signal game_started
signal game_paused
signal game_resumed
signal game_over
signal day_changed(day: int)
signal money_changed(amount: int)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MENU
var current_day: int = 1
var total_play_time: float = 0.0
var company_name: String = "My Tycoon Co."

@onready var economy: Node = %EconomyManager
@onready var time: Node = %TimeManager
@onready var buildings: Node = %BuildingSystem
@onready var ui: CanvasLayer = %UIManager


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	time.day_started.connect(_on_day_started)


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		total_play_time += delta


func start_game() -> void:
	current_state = GameState.PLAYING
	current_day = 1
	economy.reset()
	buildings.clear_all()
	ui.show_hud()
	game_started.emit()


func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		ui.show_pause_menu()
		game_paused.emit()


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		ui.hide_pause_menu()
		game_resumed.emit()


func end_game() -> void:
	current_state = GameState.GAME_OVER
	get_tree().paused = true
	ui.show_game_over()
	game_over.emit()


func _on_day_started(day: int) -> void:
	current_day = day
	day_changed.emit(day)
	economy.process_daily_income()
	economy.process_daily_expenses()
	money_changed.emit(economy.money)
