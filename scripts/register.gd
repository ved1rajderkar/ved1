extends Node3D

signal negotiation_started(customer: Node3D)
signal negotiation_ended(customer: Node3D, accepted: bool, price: int)
signal sale_completed(item_type: String, price: int)

@export var player_detection_range: float = 3.0
@export var customer_detection_range: float = 2.0
@export var base_prices: Dictionary = {
	"phone": 150,
	"headset": 120,
	"laptop": 350,
	"console": 200,
	"tv": 500,
}
@export var min_price_multiplier: float = 0.70
@export var max_price_multiplier: float = 1.30
@export var haggle_ui_scene_path: String = ""

var active_customer: Node3D = null
var is_negotiating: bool = false
var current_offer_price: int = 0
var current_item_type: String = ""
var player_in_range: bool = false
var player_node: Node3D = null

var _negotiation_ui: Control = null
var _offer_label: Label = null
var _item_label: Label = null
var _accept_btn: Button = null
var _reject_btn: Button = null
var _status_label: Label = null
var _fade_label: Label = null
var _fade_tween: Tween = null
var _result_tween: Tween = null

var _area_3d: Area3D = null
var _customer_area: Area3D = null


func _ready() -> void:
	add_to_group("register")
	add_to_group("register_area")
	_ensure_areas()
	_create_negotiation_ui()
	_find_player()
	_connect_customer_signals()


func _ensure_areas() -> void:
	_area_3d = Area3D.new()
	_area_3d.name = "RegisterArea"
	_area_3d.collision_layer = 0
	_area_3d.collision_mask = 2
	var player_col: CollisionShape3D = CollisionShape3D.new()
	var player_shape: SphereShape3D = SphereShape3D.new()
	player_shape.radius = player_detection_range
	player_col.shape = player_shape
	player_col.position = Vector3(0.0, 0.5, 0.0)
	_area_3d.add_child(player_col)
	add_child(_area_3d)
	_area_3d.body_entered.connect(_on_player_area_entered)
	_area_3d.body_exited.connect(_on_player_area_exited)

	_customer_area = Area3D.new()
	_customer_area.name = "CustomerArea"
	_customer_area.collision_layer = 0
	_customer_area.collision_mask = 4
	var customer_col: CollisionShape3D = CollisionShape3D.new()
	var customer_shape: SphereShape3D = SphereShape3D.new()
	customer_shape.radius = customer_detection_range
	customer_col.shape = customer_shape
	customer_col.position = Vector3(0.0, 0.5, -1.0)
	_customer_area.add_child(customer_col)
	add_child(_customer_area)
	_customer_area.body_entered.connect(_on_customer_area_entered)
	_customer_area.body_exited.connect(_on_customer_area_exited)


func _find_player() -> void:
	player_node = get_tree().root.get_node_or_null("Main/Player")
	if player_node == null:
		player_node = get_tree().root.get_node_or_null("Main/WorldBuilder/Characters/Player")


func _connect_customer_signals() -> void:
	var customers: Array[Node] = get_tree().get_nodes_in_group("customers")
	for customer: Node in customers:
		if customer.has_signal("negotiation_needed"):
			if not customer.negotiation_needed.is_connected(_on_customer_negotiation_needed):
				customer.negotiation_needed.connect(_on_customer_negotiation_needed)


func _create_negotiation_ui() -> void:
	_negotiation_ui = Control.new()
	_negotiation_ui.name = "NegotiationUI"
	_negotiation_ui.visible = false
	_negotiation_ui.set_anchors_preset(Control.PRESET_CENTER)
	_negotiation_ui.offset_left = -220.0
	_negotiation_ui.offset_right = 220.0
	_negotiation_ui.offset_top = -130.0
	_negotiation_ui.offset_bottom = 130.0
	_negotiation_ui.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.08, 0.12, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_negotiation_ui.add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 15)
	_negotiation_ui.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "CUSTOMER OFFER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)

	var separator1: HSeparator = HSeparator.new()
	separator1.name = "Sep1"
	vbox.add_child(separator1)

	_item_label = Label.new()
	_item_label.name = "ItemLabel"
	_item_label.text = "Item: Phone"
	_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_item_label)

	_offer_label = Label.new()
	_offer_label.name = "OfferLabel"
	_offer_label.text = "Customer offers: $150"
	_offer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_offer_label)

	var separator2: HSeparator = HSeparator.new()
	separator2.name = "Sep2"
	vbox.add_child(separator2)

	var hint_label: Label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "Press [Y] to Accept  |  Press [N] to Reject"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint_label)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	_accept_btn = Button.new()
	_accept_btn.name = "AcceptBtn"
	_accept_btn.text = "ACCEPT [Y]"
	_accept_btn.custom_minimum_size = Vector2(140, 35)
	_accept_btn.pressed.connect(_on_accept_pressed)
	btn_row.add_child(_accept_btn)

	_reject_btn = Button.new()
	_reject_btn.name = "RejectBtn"
	_reject_btn.text = "REJECT [N]"
	_reject_btn.custom_minimum_size = Vector2(140, 35)
	_reject_btn.pressed.connect(_on_reject_pressed)
	btn_row.add_child(_reject_btn)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_status_label)

	_fade_label = Label.new()
	_fade_label.name = "FadeLabel"
	_fade_label.text = ""
	_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_label.visible = false
	_fade_label.set_anchors_preset(Control.PRESET_CENTER)
	_fade_label.offset_left = -200.0
	_fade_label.offset_right = 200.0
	_fade_label.offset_top = -30.0
	_fade_label.offset_bottom = 30.0
	_fade_label.add_theme_font_size_override("font_size", 28)
	_negotiation_ui.add_child(_fade_label)

	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.name = "RegisterCanvas"
	canvas_layer.layer = 15
	add_child(canvas_layer)
	canvas_layer.add_child(_negotiation_ui)


func _unhandled_input(event: InputEvent) -> void:
	if not is_negotiating:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Y:
				_on_accept_pressed()
				get_viewport().set_input_as_handled()
			KEY_N:
				_on_reject_pressed()
				get_viewport().set_input_as_handled()


func _on_player_area_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = true


func _on_player_area_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = false


func _on_customer_area_entered(body: Node3D) -> void:
	if not body.is_in_group("customers"):
		return
	if active_customer != null:
		return
	var customer_state: int = body.get("current_state")
	if customer_state != null and customer_state == 3:
		_begin_negotiation(body)


func _on_customer_area_exited(body: Node3D) -> void:
	if body == active_customer:
		if is_negotiating:
			_end_negotiation(false)


func _on_customer_negotiation_needed(customer: Node3D, item_type: String) -> void:
	if active_customer != null:
		return
	_begin_negotiation(customer)


func _begin_negotiation(customer: Node3D) -> void:
	active_customer = customer
	is_negotiating = true
	current_item_type = customer.get_selected_item_type() if customer.has_method("get_selected_item_type") else "phone"
	var base_price: int = base_prices.get(current_item_type, 100)
	var multiplier: float = randf_range(min_price_multiplier, max_price_multiplier)
	current_offer_price = int(base_price * multiplier)
	current_offer_price = maxi(current_offer_price, 10)
	_update_ui_display()
	_negotiation_ui.visible = true
	negotiation_started.emit(customer)
	var player: Node3D = _find_player_node()
	if player and player.has_method("end_negotiation"):
		pass
	_update_status("A customer wants to buy your " + _capitalize_item(current_item_type) + "!")


func _end_negotiation(accepted: bool) -> void:
	if active_customer == null:
		return
	var customer: Node3D = active_customer
	var item: String = current_item_type
	var price: int = current_offer_price
	is_negotiating = false
	_negotiation_ui.visible = false
	var player: Node3D = _find_player_node()
	if player and player.has_method("end_negotiation"):
		player.end_negotiation()
	if accepted:
		Economy.add_money(price)
		_show_fade_text("+$%d" % price, Color(0.2, 0.9, 0.3))
		sale_completed.emit(item, price)
		customer.accept_deal() if customer.has_method("accept_deal") else null
	else:
		_show_fade_text("REJECTED", Color(0.9, 0.2, 0.2))
		customer.reject_deal() if customer.has_method("reject_deal") else null
	negotiation_ended.emit(customer, accepted, price)
	active_customer = null


func _on_accept_pressed() -> void:
	if not is_negotiating:
		return
	_end_negotiation(true)


func _on_reject_pressed() -> void:
	if not is_negotiating:
		return
	_end_negotiation(false)


func _update_ui_display() -> void:
	if _item_label:
		_item_label.text = "Item: " + _capitalize_item(current_item_type)
	if _offer_label:
		_offer_label.text = "Customer offers: $%d" % current_offer_price


func _update_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


func _show_fade_text(text: String, color: Color) -> void:
	if _fade_label == null:
		return
	_fade_label.text = text
	_fade_label.visible = true
	_fade_label.modulate = Color(1, 1, 1, 1)
	_fade_label.add_theme_color_override("font_color", color)
	_fade_label.position.y = 0.0
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(_fade_label, "modulate:a", 0.0, 1.5).set_delay(0.5)
	_fade_tween.tween_property(_fade_label, "position:y", -40.0, 1.5).set_delay(0.5)
	_fade_tween.chain().tween_callback(func() -> void: _fade_label.visible = false)


func _capitalize_item(item: String) -> String:
	match item:
		"phone":
			return "Headset"
		"headset":
			return "Headset"
		"laptop":
			return "Laptop"
		"console":
			return "Console"
		"tv":
			return "TV"
		_:
			return item.capitalize()


func _find_player_node() -> Node3D:
	if player_node != null and is_instance_valid(player_node):
		return player_node
	player_node = get_tree().root.get_node_or_null("Main/Player")
	return player_node


func get_base_price(item_type: String) -> int:
	return base_prices.get(item_type, 100)


func get_current_offer() -> int:
	return current_offer_price


func is_active() -> bool:
	return is_negotiating


func get_active_customer() -> Node3D:
	return active_customer
