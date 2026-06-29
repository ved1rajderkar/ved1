extends CharacterBody3D

signal skin_changed(skin_name: String)
signal animations_loaded(count: int)

const MODEL_PATH: String = "res://assets/player/Model/characterMedium.fbx"
const SKINS_DIR: String = "res://assets/player/Skins"
const ANIMS_DIR: String = "res://assets/player/Animations"

@export var move_speed: float = 8.0
@export var sprint_speed: float = 12.0
@export var jump_force: float = 8.0
@export var gravity_force: float = -20.0
@export var mouse_sensitivity: float = 0.002
@export var default_skin: String = ""

var current_skin: String = ""
var skin_list: Array[String] = []
var anim_list: Array[String] = []
var _skin_textures: Dictionary = {}
var _model_root: Node3D = null
var _mesh_node: MeshInstance3D = null
var _anim_player: AnimationPlayer = null
var _anim_library: AnimationLibrary = null
var _yaw: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var back_stack: Marker3D = $BackStack


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_load_all_skins()
	_load_all_animations()
	_instantiate_model()
	if default_skin != "" and _skin_textures.has(default_skin):
		apply_skin(default_skin)
	elif skin_list.size() > 0:
		apply_skin(skin_list[0])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sensitivity
		_yaw = clamp(_yaw, -2.5, 2.5)
		rotation.y = _yaw
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.pressed and event.keycode == KEY_TAB:
			next_skin()
		if event.pressed and event.keycode == KEY_F5:
			apply_skin(default_skin if default_skin != "" else skin_list[0] if skin_list.size() > 0 else "")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity_force * delta

	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var move_dir: Vector3 = (forward * input_dir.y + right * input_dir.x).normalized()

	var speed: float = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	if move_dir != Vector3.ZERO:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 10)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force

	move_and_slide()
	_play_movement_anim(move_dir.length() > 0.1)


func _play_movement_anim(moving: bool) -> void:
	if _anim_player == null:
		return
	if moving:
		if _anim_player.current_animation != "run":
			_anim_player.play("run", 0.15)
	else:
		if _anim_player.current_animation != "idle":
			_anim_player.play("idle", 0.3)


func _load_all_skins() -> void:
	skin_list.clear()
	_skin_textures.clear()
	var dir: DirAccess = DirAccess.open(SKINS_DIR)
	if dir == null:
		push_warning("PlayerSetup: Cannot open " + SKINS_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png"):
			var sname: String = fname.get_basename()
			var tex: Texture2D = load(SKINS_DIR + "/" + fname) as Texture2D
			if tex != null:
				skin_list.append(sname)
				_skin_textures[sname] = tex
		fname = dir.get_next()
	dir.list_dir_end()


func _load_all_animations() -> void:
	anim_list.clear()
	var dir: DirAccess = DirAccess.open(ANIMS_DIR)
	if dir == null:
		push_warning("PlayerSetup: Cannot open " + ANIMS_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".fbx"):
			anim_list.append(fname.get_basename())
		fname = dir.get_next()
	dir.list_dir_end()
	animations_loaded.emit(anim_list.size())


func _instantiate_model() -> void:
	var res: Resource = load(MODEL_PATH)
	if res == null:
		push_warning("PlayerSetup: Cannot load " + MODEL_PATH)
		return
	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	add_child(_model_root)
	_model_root.position = Vector3.ZERO

	if res is PackedScene:
		var inst: Node = res.instantiate()
		_model_root.add_child(inst)
		_find_mesh(inst)
	elif res is Mesh:
		_mesh_node = MeshInstance3D.new()
		_mesh_node.mesh = res
		_model_root.add_child(_mesh_node)

	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	_model_root.add_child(_anim_player)

	_anim_library = AnimationLibrary.new()
	_anim_player.add_library("default", _anim_library)

	for aname in anim_list:
		var ares: Resource = load(ANIMS_DIR + "/" + aname + ".fbx")
		if ares == null:
			continue
		if ares is Animation:
			_anim_library.add_animation(aname, ares)
		elif ares is PackedScene:
			var ainst: Node = ares.instantiate()
			if ainst is AnimationPlayer:
				for li in range(ainst.get_animation_library_count()):
					var ln: String = ainst.get_animation_library_name(li)
					var lib: AnimationLibrary = ainst.get_animation_library(ln)
					for sn in lib.get_animation_list():
						var anim: Animation = lib.get_animation(sn)
						if anim != null and not _anim_library.has_animation(sn):
							_anim_library.add_animation(sn, anim)
			ainst.queue_free()

	if _anim_library.get_animation_count() > 0:
		_anim_player.play("idle" if _anim_library.has_animation("idle") else _anim_library.get_animation_name(0))


func _find_mesh(node: Node) -> void:
	if _mesh_node != null:
		return
	if node is MeshInstance3D:
		_mesh_node = node
		return
	for child in node.get_children():
		_find_mesh(child)


func apply_skin(skin_name: String) -> void:
	if not _skin_textures.has(skin_name):
		push_warning("PlayerSetup: Skin not found: " + skin_name)
		return
	if _mesh_node == null or _mesh_node.mesh == null:
		push_warning("PlayerSetup: No mesh to apply skin to")
		return
	var tex: Texture2D = _skin_textures[skin_name]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.8
	var count: int = _mesh_node.mesh.get_surface_count()
	for i in range(count):
		_mesh_node.set_surface_override_material(i, mat)
	current_skin = skin_name
	skin_changed.emit(skin_name)


func next_skin() -> void:
	if skin_list.is_empty():
		return
	var idx: int = skin_list.find(current_skin)
	idx = (idx + 1) % skin_list.size()
	apply_skin(skin_list[idx])


func prev_skin() -> void:
	if skin_list.is_empty():
		return
	var idx: int = skin_list.find(current_skin)
	idx = (idx - 1 + skin_list.size()) % skin_list.size()
	apply_skin(skin_list[idx])


func play_anim(anim_name: String, blend: float = 0.2) -> void:
	if _anim_player != null and _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name, blend)


func stop_anim() -> void:
	if _anim_player != null:
		_anim_player.stop()
