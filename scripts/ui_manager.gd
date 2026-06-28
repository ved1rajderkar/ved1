extends CanvasLayer

## Manages all UI: HUD, menus, building panel, notifications.

signal build_button_pressed(building_type: String)
signal speed_button_pressed(speed: float)
signal pause_button_pressed
signal resume_button_pressed

var is_hud_visible: bool = false
var is_menu_open: bool = false

@onready var hud_panel: Control = %HUDPanel
@onready var build_menu: Control = %BuildMenu
@onready var pause_menu: Control = %PauseMenu
@onready var game_over_panel: Control = %GameOverPanel
@onready var notification_label: Label = %NotificationLabel
@onready var money_label: Label = %MoneyLabel
@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var speed_label: Label = %SpeedLabel
@onready var income_label: Label = %IncomeLabel


func _ready() -> void:
	hide_all()
	_connect_economy_signals()


func _connect_economy_signals() -> void:
	var economy: Node = get_node_or_null("/root/Main/EconomyManager")
	if economy:
		economy.money_changed.connect(_on_money_changed)
		economy.income_changed.connect(_on_income_changed)


func _on_money_changed(amount: int) -> void:
	if money_label:
		money_label.text = "$%d" % amount


func _on_income_changed(amount: int) -> void:
	if income_label:
		income_label.text = "+$%d/day" % amount


func show_hud() -> void:
	is_hud_visible = true
	hud_panel.visible = true
	build_menu.visible = false
	pause_menu.visible = false
	game_over_panel.visible = false


func hide_all() -> void:
	is_hud_visible = false
	hud_panel.visible = false
	build_menu.visible = false
	pause_menu.visible = false
	game_over_panel.visible = false


func toggle_build_menu() -> void:
	build_menu.visible = !build_menu.visible
	is_menu_open = build_menu.visible


func hide_build_menu() -> void:
	build_menu.visible = false
	is_menu_open = false


func show_pause_menu() -> void:
	pause_menu.visible = true
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS


func hide_pause_menu() -> void:
	pause_menu.visible = false


func show_game_over() -> void:
	game_over_panel.visible = true
	game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS


func update_time_display(day: int, formatted_time: String, day_name: String) -> void:
	if day_label:
		day_label.text = "Day %d - %s" % [day, day_name]
	if time_label:
		time_label.text = formatted_time


func update_speed_display(speed: float) -> void:
	if speed_label:
		speed_label.text = "%.1fx" % speed


func show_notification(text: String, duration: float = 3.0) -> void:
	if notification_label:
		notification_label.text = text
		notification_label.visible = true
		var timer: Timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.timeout.connect(func() -> void:
			notification_label.visible = false
			timer.queue_free()
		)
		add_child(timer)
		timer.start()


func update_resource_display(resources: Dictionary) -> void:
	# Can be extended with dedicated resource labels
	pass


func _on_build_button_pressed(building_type: String) -> void:
	build_button_pressed.emit(building_type)


func _on_speed_button_pressed(speed: float) -> void:
	speed_button_pressed.emit(speed)


func _on_pause_pressed() -> void:
	pause_button_pressed.emit()


func _on_resume_pressed() -> void:
	resume_button_pressed.emit()
