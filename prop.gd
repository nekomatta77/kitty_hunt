extends CharacterBody3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0 
const JUMP_VELOCITY = 4.5
var mouse_sensitivity = 0.002
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var health = 100.0 

@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D
@onready var raycast = $SpringArm3D/Camera3D/RayCast3D
@onready var mesh_instance = $MeshInstance3D
@onready var collision_shape = $CollisionShape3D
@onready var mobile_ui = $MobileUI

var original_health_bar = null
var custom_hp_bar: ProgressBar
var fg_style: StyleBoxFlat

func _ready():
	spring_arm.add_excluded_object(self.get_rid())
	
	if mobile_ui:
		for child in mobile_ui.get_children():
			if child.has_method("set_health"):
				original_health_bar = child
				child.hide() 
	
	if is_multiplayer_authority():
		camera.current = true
		_setup_beautiful_ui()
		update_hp_visual(health)

func _setup_beautiful_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var center_box = CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center_box)
	
	# === ВОТ НАШ СКРИПТОВЫЙ ПРИЦЕЛ ===
	var crosshair = Panel.new()
	crosshair.custom_minimum_size = Vector2(8, 8)
	var ch_style = StyleBoxFlat.new()
	ch_style.bg_color = Color(1, 1, 1, 0.6) # Полупрозрачный белый
	ch_style.set_corner_radius_all(4) # Круглая точка
	crosshair.add_theme_stylebox_override("panel", ch_style)
	center_box.add_child(crosshair)
	
	# === ПОЛОСКА ЗДОРОВЬЯ ===
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.add_theme_constant_override("margin_bottom", 40)
	canvas.add_child(margin)
	
	custom_hp_bar = ProgressBar.new()
	custom_hp_bar.custom_minimum_size = Vector2(400, 35)
	custom_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_hp_bar.show_percentage = false
	custom_hp_bar.max_value = 100
	custom_hp_bar.value = health
	
	var modern_font = SystemFont.new()
	modern_font.font_names = PackedStringArray(["Montserrat", "Segoe UI", "sans-serif"])
	modern_font.font_weight = 700
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.set_corner_radius_all(16)
	bg_style.set_border_width_all(2)
	bg_style.border_color = Color(0.3, 0.3, 0.3)
	
	fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(0.2, 0.6, 0.9) 
	fg_style.set_corner_radius_all(16)
	
	custom_hp_bar.add_theme_stylebox_override("background", bg_style)
	custom_hp_bar.add_theme_stylebox_override("fill", fg_style)
	
	var label = Label.new()
	label.text = "ЗДОРОВЬЕ МАСКИРОВКИ"
	label.add_theme_font_override("font", modern_font)
	label.add_theme_font_size_override("font_size", 16)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_hp_bar.add_child(label)
	margin.add_child(custom_hp_bar)

func update_hp_visual(new_health: float):
	if custom_hp_bar:
		custom_hp_bar.value = new_health
		if new_health <= 30:
			fg_style.bg_color = Color(0.9, 0.3, 0.2)
		else:
			fg_style.bg_color = Color(0.2, 0.6, 0.9)
			
	if original_health_bar:
		original_health_bar.set_health(new_health)

func _enter_tree():
	var id = name.to_int()
	if id == 0: id = 1 
	set_multiplayer_authority(id)

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
		
	var is_valid_drag = false
	if event is InputEventMouseMotion:
		is_valid_drag = true
	elif event is InputEventScreenDrag:
		if event.position.x > get_viewport().size.x / 2.0:
			is_valid_drag = true

	if is_valid_drag:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60), deg_to_rad(45))
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		try_transform()

func try_transform():
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var target = raycast.get_collider()
		if target.is_in_group("props"):
			rpc("sync_transform", str(target.get_path()))

@rpc("authority", "call_local", "reliable")
func sync_transform(target_path: String):
	var target = get_node_or_null(target_path)
	if target and target.has_node("MeshInstance3D") and target.has_node("CollisionShape3D"):
		mesh_instance.mesh = target.get_node("MeshInstance3D").mesh
		collision_shape.shape = target.get_node("CollisionShape3D").shape

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY

	var h_axis = int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	if h_axis == 0: h_axis = Input.get_axis("ui_left", "ui_right")
	var v_axis = int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	if v_axis == 0: v_axis = Input.get_axis("ui_up", "ui_down")

	var input_dir = Vector2(h_axis, v_axis).normalized()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed = WALK_SPEED
	if Input.is_physical_key_pressed(KEY_SHIFT):
		current_speed = SPRINT_SPEED
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

@rpc("any_peer", "call_local", "reliable")
func receive_damage(amount: float):
	if is_multiplayer_authority():
		health -= amount
		update_hp_visual(health)
		
		if health <= 0:
			rpc("die_rpc") 
		else:
			rpc("sync_health", health) 

@rpc("authority", "call_remote", "reliable")
func sync_health(new_health: float):
	health = new_health
	if is_multiplayer_authority():
		update_hp_visual(new_health)

@rpc("authority", "call_local", "reliable")
func die_rpc():
	queue_free() 
	
	if multiplayer.is_server():
		var level = get_tree().current_scene
		if level and level.has_method("check_hunter_win"):
			level.check_hunter_win()
