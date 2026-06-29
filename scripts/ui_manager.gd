extends CanvasLayer

signal build_selected(btype: String)
signal upgrade_pressed
signal sell_pressed
signal speed_pressed(speed: float)
signal start_pressed
signal resume_pressed
signal restart_pressed
signal save_pressed

@onready var hud: Control = $HUD
@onready var build_panel: Control = $BuildPanel
@onready var pause_panel: Control = $PausePanel
@onready var gameover_panel: Control = $GameOverPanel
@onready var notification_label: Label = $Notification
@onready var start_panel: Control = $StartPanel
@onready var upgrade_panel: Control = $UpgradePanel

@onready var money_label: Label = $HUD/MoneyRow/MoneyLabel
@onready var income_label: Label = $HUD/MoneyRow/IncomeLabel
@onready var day_label: Label = $HUD/TimeRow/DayLabel
@onready var time_label: Label = $HUD/TimeRow/TimeLabel
@onready var speed_label: Label = $HUD/TimeRow/SpeedLabel
@onready var workers_label: Label = $HUD/ResourceRow/WorkersLabel
@onready var materials_label: Label = $HUD/ResourceRow/MaterialsLabel
@onready var happiness_label: Label = $HUD/ResourceRow/HappinessLabel
@onready var reputation_label: Label = $HUD/ResourceRow/ReputationLabel
@onready var buildings_label: Label = $HUD/InfoRow/BuildingsLabel
@onready var profit_label: Label = $HUD/MoneyRow/ProfitLabel

@onready var build_grid: GridContainer = $BuildPanel/Panel/MarginContainer/VBoxContainer/ScrollContainer/BuildGrid
@onready var upgrade_name: Label = $UpgradePanel/Panel/MarginContainer/VBoxContainer/NameLabel
@onready var upgrade_level: Label = $UpgradePanel/Panel/MarginContainer/VBoxContainer/LevelLabel
@onready var upgrade_cost_label: Label = $UpgradePanel/Panel/MarginContainer/VBoxContainer/CostLabel
@onready var upgrade_income_label: Label = $UpgradePanel/Panel/MarginContainer/VBoxContainer/IncomeLabel
@onready var gameover_reason: Label = $GameOverPanel/Panel/MarginContainer/VBoxContainer/ReasonLabel

var notify_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.set_meta("UIManager", self)
	hide_all()
	show_start_screen()
	_connect_signals()
	_connect_buttons()


func _connect_signals() -> void:
	Economy.money_changed.connect(_on_money_changed)
	Economy.income_changed.connect(_on_income_changed)
	Economy.resource_changed.connect(_on_resource_changed)
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.speed_changed.connect(_on_speed_changed)
	GameManager.day_advanced.connect(_on_day_advanced)
	GameManager.game_over.connect(_on_game_over)
	var bs: Node3D = _get_building_system()
	if bs:
		bs.building_placed.connect(_on_building_placed)
		bs.building_upgraded.connect(_on_building_upgraded)
		bs.placement_failed.connect(_on_placement_failed)


func _get_building_system() -> Node3D:
	var root: Node = get_tree().root
	return root.get_node_or_null("Main/BuildingSystem")


func _connect_buttons() -> void:
	var start_btn: Button = $StartPanel/Panel/MarginContainer/VBoxContainer/StartButton
	start_btn.pressed.connect(_on_start_pressed)

	var pause_btn: Button = $HUD/PauseBtn
	pause_btn.pressed.connect(_on_pause_pressed)

	var build_btn: Button = $HUD/BuildBtn
	build_btn.pressed.connect(_on_build_btn_pressed)

	var close_build: Button = $BuildPanel/Panel/MarginContainer/VBoxContainer/CloseBtn
	close_build.pressed.connect(_on_close_build_pressed)

	var upgrade_btn: Button = $UpgradePanel/Panel/MarginContainer/VBoxContainer/UpgradeButton
	upgrade_btn.pressed.connect(_on_upgrade_pressed)

	var sell_btn: Button = $UpgradePanel/Panel/MarginContainer/VBoxContainer/SellButton
	sell_btn.pressed.connect(_on_sell_pressed)

	var close_upgrade: Button = $UpgradePanel/Panel/MarginContainer/VBoxContainer/CloseButton
	close_upgrade.pressed.connect(_on_close_upgrade_pressed)

	var resume_btn: Button = $PausePanel/Panel/MarginContainer/VBoxContainer/ResumeButton
	resume_btn.pressed.connect(_on_resume_pressed)

	var save_btn: Button = $PausePanel/Panel/MarginContainer/VBoxContainer/SaveButton
	save_btn.pressed.connect(_on_save_pressed)

	var restart_pause: Button = $PausePanel/Panel/MarginContainer/VBoxContainer/RestartButton
	restart_pause.pressed.connect(_on_restart_pressed)

	var restart_go: Button = $GameOverPanel/Panel/MarginContainer/VBoxContainer/RestartButton
	restart_go.pressed.connect(_on_restart_pressed)

	var s1: Button = $HUD/SpeedButtons/Speed1
	s1.pressed.connect(func() -> void: speed_pressed.emit(1.0))
	var s2: Button = $HUD/SpeedButtons/Speed2
	s2.pressed.connect(func() -> void: speed_pressed.emit(2.0))
	var s3: Button = $HUD/SpeedButtons/Speed3
	s3.pressed.connect(func() -> void: speed_pressed.emit(3.0))
	var s4: Button = $HUD/SpeedButtons/Speed4
	s4.pressed.connect(func() -> void: speed_pressed.emit(4.0))


func _process(delta: float) -> void:
	if notify_timer > 0:
		notify_timer -= delta
		if notify_timer <= 0:
			notification_label.visible = false


func hide_all() -> void:
	hud.visible = false
	build_panel.visible = false
	pause_panel.visible = false
	gameover_panel.visible = false
	upgrade_panel.visible = false
	start_panel.visible = false
	notification_label.visible = false


func show_start_screen() -> void:
	hide_all()
	start_panel.visible = true


func show_hud() -> void:
	start_panel.visible = false
	hud.visible = true
	build_panel.visible = false
	pause_panel.visible = false
	gameover_panel.visible = false
	upgrade_panel.visible = false
	_refresh_all()


func toggle_build_menu() -> void:
	if build_panel.visible:
		build_panel.visible = false
		upgrade_panel.visible = false
		return
	build_panel.visible = true
	upgrade_panel.visible = false
	_populate_build_menu()


func show_upgrade_panel(building: Node3D) -> void:
	var btype: String = building.get_meta("building_type", "")
	var data: Dictionary = BuildingData.get_building(btype)
	var level: int = building.get_meta("level", 1)
	var max_level: int = BuildingData.get_max_level(btype)
	upgrade_name.text = data.get("name", "Unknown")
	upgrade_level.text = "Level %d / %d" % [level, max_level]
	if level < max_level:
		var cost: int = BuildingData.get_upgrade_cost(btype, level)
		upgrade_cost_label.text = "Upgrade Cost: $%d" % cost
		upgrade_cost_label.visible = true
	else:
		upgrade_cost_label.text = "MAX LEVEL"
		upgrade_cost_label.visible = true
	upgrade_income_label.text = "Income: $%d/day" % int(data.get("income", 0) * level)
	upgrade_panel.visible = true


func hide_upgrade_panel() -> void:
	upgrade_panel.visible = false


func show_pause() -> void:
	pause_panel.visible = true
	hud.visible = false


func hide_pause() -> void:
	pause_panel.visible = false
	hud.visible = true


func show_game_over(reason: String) -> void:
	hide_all()
	gameover_panel.visible = true
	gameover_reason.text = reason


func show_notification(text: String, duration: float = 3.0) -> void:
	notification_label.text = text
	notification_label.visible = true
	notify_timer = duration


func _refresh_all() -> void:
	_on_money_changed(Economy.money)
	_on_income_changed(Economy.daily_income)
	_on_resource_changed("workers", Economy.workers)
	_on_resource_changed("materials", Economy.materials)
	_on_resource_changed("happiness", Economy.happiness)
	_on_resource_changed("reputation", Economy.reputation)
	_on_hour_changed(TimeManager.current_hour)
	_on_speed_changed(TimeManager.game_speed)
	var bs: Node3D = _get_building_system()
	if buildings_label and bs:
		buildings_label.text = "Buildings: %d" % bs.get_total_buildings()


func _on_money_changed(amount: int) -> void:
	if money_label:
		money_label.text = "$%d" % amount


func _on_income_changed(amount: int) -> void:
	if income_label:
		income_label.text = "Income: $%d/day" % amount


func _on_resource_changed(resource: String, value: int) -> void:
	match resource:
		"workers":
			if workers_label:
				workers_label.text = "Workers: %d" % value
		"materials":
			if materials_label:
				materials_label.text = "Materials: %d" % value
		"happiness":
			if happiness_label:
				happiness_label.text = "Happiness: %d%%" % value
		"reputation":
			if reputation_label:
				reputation_label.text = "Rep: %d" % value


func _on_hour_changed(_hour: int) -> void:
	if day_label:
		day_label.text = GameManager.get_day_string()
	if time_label:
		time_label.text = TimeManager.get_time_string()
	if profit_label:
		var profit: int = Economy.get_profit()
		profit_label.text = "Profit: $%d/day" % profit
		if profit >= 0:
			profit_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
		else:
			profit_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))


func _on_speed_changed(_speed: float) -> void:
	if speed_label:
		speed_label.text = TimeManager.get_speed_label()


func _on_day_advanced(_day: int) -> void:
	var bs: Node3D = _get_building_system()
	if buildings_label and bs:
		buildings_label.text = "Buildings: %d" % bs.get_total_buildings()
	show_notification("Day %d begins. Income: $%d/day" % [GameManager.current_day, Economy.daily_income])


func _on_building_placed(_building: Node3D, btype: String) -> void:
	var data: Dictionary = BuildingData.get_building(btype)
	show_notification("Built: %s" % data.get("name", btype))
	var bs: Node3D = _get_building_system()
	if buildings_label and bs:
		buildings_label.text = "Buildings: %d" % bs.get_total_buildings()


func _on_building_upgraded(building: Node3D, new_level: int) -> void:
	var data: Dictionary = BuildingData.get_building(building.get_meta("building_type", ""))
	show_notification("Upgraded %s to Lv%d!" % [data.get("name", ""), new_level])
	show_upgrade_panel(building)


func _on_placement_failed(reason: String) -> void:
	show_notification("Cannot build: " + reason, 4.0)


func _on_game_over(reason: String) -> void:
	show_game_over(reason)


func _populate_build_menu() -> void:
	for child in build_grid.get_children():
		child.queue_free()

	var types: Array[String] = BuildingData.get_all_types()
	for btype in types:
		var data: Dictionary = BuildingData.get_building(btype)
		if data.is_empty():
			continue
		var btn: Button = Button.new()
		btn.text = "%s - $%d" % [data.get("name", btype), data.get("cost", 0)]
		btn.tooltip_text = data.get("description", "")
		btn.custom_minimum_size = Vector2(190, 36)
		var captured_type: String = btype
		btn.pressed.connect(func() -> void:
			build_selected.emit(captured_type)
			build_panel.visible = false
			var bs: Node3D = _get_building_system()
			if bs:
				bs.start_placement(captured_type)
		)
		build_grid.add_child(btn)


func _on_start_pressed() -> void:
	start_pressed.emit()
	GameManager.start_game()


func _on_pause_pressed() -> void:
	GameManager.toggle_pause()


func _on_resume_pressed() -> void:
	resume_pressed.emit()
	GameManager.resume_game()


func _on_restart_pressed() -> void:
	restart_pressed.emit()
	GameManager.restart_game()


func _on_save_pressed() -> void:
	save_pressed.emit()
	if SaveSystem.save_game():
		show_notification("Game saved!")
	else:
		show_notification("Save failed!")


func _on_build_btn_pressed() -> void:
	toggle_build_menu()


func _on_upgrade_pressed() -> void:
	upgrade_pressed.emit()
	var bs: Node3D = _get_building_system()
	if bs and bs.selected_building:
		bs.upgrade_building(bs.selected_building)


func _on_sell_pressed() -> void:
	sell_pressed.emit()
	var bs: Node3D = _get_building_system()
	if bs and bs.selected_building:
		bs.remove_building(bs.selected_building)
		upgrade_panel.visible = false


func _on_close_build_pressed() -> void:
	build_panel.visible = false
	var bs: Node3D = _get_building_system()
	if bs:
		bs.cancel_placement()


func _on_close_upgrade_pressed() -> void:
	upgrade_panel.visible = false
	var bs: Node3D = _get_building_system()
	if bs:
		bs.deselect_building()
