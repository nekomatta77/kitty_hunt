extends CharacterBody3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0 
const JUMP_VELOCITY = 4.5
var mouse_sensitivity = 0.002
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var health = 100.0 

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var mobile_ui = $MobileUI 

var original_health_bar = null
var custom_hp_bar: ProgressBar
var hitmarker_node: Control
var hm_tween: Tween
var fg_style: StyleBoxFlat

func _enter_tree():
	var id = name.to_int()
	if id == 0: id = 1 
	set_multiplayer_authority(id)

func _ready():
	raycast.add_exception(self)
	
	# ПАНАЦЕЯ ОТ БАГОВ ИНТЕРФЕЙСА:
	# Только МЫ владеем своим экраном. Удаляем интерфейсы чужих игроков!
	if is_multiplayer_authority():
		camera.current = true
		_setup_beautiful_ui()
		update_hp_visual(health)
		
		if mobile_ui:
			for child in mobile_ui.get_children():
				if child.has_method("set_health"):
					original_health_bar = child
					child.hide() 
	else:
		if mobile_ui:
			mobile_ui.queue_free()

func _setup_beautiful_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root_ui)
	
	var center_box = CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(center_box)
	
	var crosshair = Panel.new()
	crosshair.custom_minimum_size = Vector2(6, 6)
	var ch_style = StyleBoxFlat.new()
	ch_style.bg_color = Color(1, 1, 1, 0.8)
	ch_style.set_corner_radius_all(3)
	crosshair.add_theme_stylebox_override("panel", ch_style)
	center_box.add_child(crosshair)
	
	hitmarker_node = Control.new()
	hitmarker_node.custom_minimum_size = Vector2(40, 40)
	hitmarker_node.pivot_offset = Vector2(20, 20)
	center_box.add_child(hitmarker_node)
	
	var angles = [45, 135, 225, 315]
	for angle in angles:
		var line = ColorRect.new()
		line.color = Color(1.0, 0.8, 0.2)
		line.custom_minimum_size = Vector2(10, 3)
		line.pivot_offset = Vector2(0, 1.5)
		line.position = Vector2(20, 18.5)
		line.rotation_degrees = angle
		var rad = deg_to_rad(angle)
		line.position += Vector2(cos(rad), sin(rad)) * 8.0
		hitmarker_node.add_child(line)
		
	hitmarker_node.modulate.a = 0 
	
	var hp_margin = MarginContainer.new()
	hp_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_margin.add_theme_constant_override("margin_left", 40)
	hp_margin.add_theme_constant_override("margin_top", 40) 
	hp_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(hp_margin)
	
	var hp_vbox = VBoxContainer.new()
	hp_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN 
	hp_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN 
	hp_margin.add_child(hp_vbox)
	
	var hp_label = Label.new()
	hp_label.text = "ЗДОРОВЬЕ ОХОТНИКА"
	var modern_font = SystemFont.new()
	modern_font.font_names = PackedStringArray(["Montserrat", "Segoe UI", "sans-serif"])
	modern_font.font_weight = 800
	hp_label.add_theme_font_override("font", modern_font)
	hp_label.add_theme_font_size_override("font_size", 20)
	hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	hp_label.add_theme_constant_override("shadow_offset_y", 2)
	hp_vbox.add_child(hp_label)
	
	custom_hp_bar = ProgressBar.new()
	custom_hp_bar.custom_minimum_size = Vector2(350, 26)
	custom_hp_bar.show_percentage = false
	custom_hp_bar.max_value = 100
	custom_hp_bar.value = health
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.set_corner_radius_all(8)
	bg_style.set_border_width_all(2)
	bg_style.border_color = Color(0.0, 0.0, 0.0, 0.8)
	
	fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(0.2, 0.8, 0.3)
	fg_style.set_corner_radius_all(6)
	fg_style.set_border_width_all(2)
	fg_style.border_color = Color(0.4, 1.0, 0.5, 0.3) 
	
	custom_hp_bar.add_theme_stylebox_override("background", bg_style)
	custom_hp_bar.add_theme_stylebox_override("fill", fg_style)
	hp_vbox.add_child(custom_hp_bar)

func flash_hitmarker():
	if hitmarker_node:
		if hm_tween: hm_tween.kill()
		hitmarker_node.scale = Vector2(0.5, 0.5)
		hitmarker_node.modulate.a = 1.0
		hm_tween = create_tween().set_parallel(true)
		hm_tween.tween_property(hitmarker_node, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_SPRING)
		hm_tween.tween_property(hitmarker_node, "modulate:a", 0.0, 0.3).set_delay(0.1)

func update_hp_visual(new_health: float):
	if custom_hp_bar:
		var tween = create_tween()
		tween.tween_property(custom_hp_bar, "value", new_health, 0.2).set_trans(Tween.TRANS_SINE)
		
		if new_health <= 30:
			fg_style.bg_color = Color(0.9, 0.2, 0.2)
		else:
			fg_style.bg_color = Color(0.2, 0.8, 0.3)
			
	if original_health_bar:
		original_health_bar.set_health(new_health)

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
		
	var is_valid_drag = false
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	
	if is_mobile:
		if event is InputEventScreenDrag:
			if event.position.x > get_viewport().size.x / 2.0:
				is_valid_drag = true
	else:
		if event is InputEventMouseMotion:
			is_valid_drag = true

	if is_valid_drag:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if not is_mobile:
			shoot()

func shoot():
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var target = raycast.get_collider()
		if target != self and target.has_method("receive_damage"):
			target.rpc("receive_damage", 25.0)
			flash_hitmarker() 
		else:
			rpc("receive_damage", 10.0)
	else:
		rpc("receive_damage", 10.0)

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
	if multiplayer.is_server():
		var level = get_tree().current_scene
		if level and level.has_method("check_prop_win"):
			level.check_prop_win(self)
	queue_free()
