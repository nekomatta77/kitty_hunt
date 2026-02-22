extends Node3D

var time_left: float = 300.0 
var game_active: bool = false

var ui_layer: CanvasLayer
var timer_label: Label
var game_over_overlay: ColorRect
var game_over_panel: Panel
var result_label: Label
var return_btn: Button
var modern_font: SystemFont

func _ready():
	modern_font = SystemFont.new()
	modern_font.font_names = PackedStringArray(["Montserrat", "Segoe UI", "Roboto", "sans-serif"])
	modern_font.font_weight = 700
	
	setup_ui()
	
	if multiplayer.is_server():
		Network.spawn_player_locally(1, true)
		for id in Network.player_roles:
			if id != 1:
				Network.spawn_player_locally(id, false)
				Network.rpc("remote_spawn_player", id, false)
				Network.rpc_id(id, "remote_spawn_player", 1, true)
		
		call_deferred("start_game")

func start_game():
	game_active = true
	rpc("sync_game_state", true, 300.0)

@rpc("authority", "call_local", "reliable")
func sync_game_state(active: bool, time: float):
	game_active = active
	time_left = time

func _process(delta):
	if not game_active: return
	
	if multiplayer.is_server():
		time_left -= delta
		if time_left <= 0:
			time_left = 0
			rpc("show_game_over", false) 
		else:
			rpc("sync_time", time_left)

	update_timer_ui()

@rpc("authority", "call_remote", "unreliable")
func sync_time(time: float):
	time_left = time

func update_timer_ui():
	if not timer_label: return
	var mins = int(max(time_left, 0)) / 60
	var secs = int(max(time_left, 0)) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	
	if time_left <= 60:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 1, 1))

# === ИДЕАЛЬНАЯ МЕХАНИКА ПОБЕДЫ В РЕАЛЬНОМ ВРЕМЕНИ ===
# Теперь мы передаем умирающего игрока, чтобы игра не ждала окончания кадра!
func check_hunter_win(dying_node = null):
	if not game_active or not multiplayer.is_server(): return
	
	var alive_props = 0
	for prop in get_tree().get_nodes_in_group("player_props"):
		# Считаем живых пропов, исключая того, кто прямо сейчас умирает
		if prop != dying_node and is_instance_valid(prop) and not prop.is_queued_for_deletion():
			alive_props += 1
			
	if alive_props <= 0 and game_active:
		rpc("show_game_over", true)

func check_prop_win(dying_node = null):
	if not game_active or not multiplayer.is_server(): return
	
	var alive_hunters = 0
	for hunter in get_tree().get_nodes_in_group("player_hunters"):
		if hunter != dying_node and is_instance_valid(hunter) and not hunter.is_queued_for_deletion():
			alive_hunters += 1
			
	if alive_hunters <= 0 and game_active:
		rpc("show_game_over", false)

@rpc("authority", "call_local", "reliable")
func show_game_over(hunter_won: bool):
	game_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) 
	
	timer_label.hide()
	game_over_overlay.show()
	
	game_over_panel.pivot_offset = game_over_panel.custom_minimum_size / 2
	game_over_panel.scale = Vector2.ZERO
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(game_over_panel, "scale", Vector2.ONE, 0.5)
	
	if hunter_won:
		result_label.text = "ПОБЕДА ОХОТНИКА!\n\nВсе пропы уничтожены"
		result_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	else:
		result_label.text = "ПОБЕДА ПРОПОВ!\n\nОхотник не справился"
		result_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		
	if multiplayer.is_server():
		return_btn.show()
	else:
		return_btn.hide()

func setup_ui():
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	timer_label = Label.new()
	timer_label.text = "05:00"
	timer_label.add_theme_font_override("font", modern_font)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 64)
	timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	timer_label.add_theme_constant_override("shadow_offset_x", 3)
	timer_label.add_theme_constant_override("shadow_offset_y", 3)
	ui_layer.add_child(timer_label)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	timer_label.position.y += 20
	
	game_over_overlay = ColorRect.new()
	game_over_overlay.color = Color(0, 0, 0, 0.7)
	game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.hide()
	ui_layer.add_child(game_over_overlay)
	
	var center_box = CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.add_child(center_box)
	
	game_over_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_corner_radius_all(24)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.3)
	style.shadow_color = Color(0, 0, 0, 0.8)
	style.shadow_size = 30
	game_over_panel.add_theme_stylebox_override("panel", style)
	
	game_over_panel.custom_minimum_size = Vector2(500, 350)
	center_box.add_child(game_over_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 50)
	game_over_panel.add_child(vbox)
	
	result_label = Label.new()
	result_label.add_theme_font_override("font", modern_font)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 34)
	result_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	vbox.add_child(result_label)
	
	return_btn = Button.new()
	return_btn.text = "ВЕРНУТЬСЯ В ЛОББИ"
	return_btn.add_theme_font_override("font", modern_font)
	return_btn.add_theme_font_size_override("font_size", 22)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.6, 0.9)
	btn_style.set_corner_radius_all(12)
	return_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.35, 0.7, 1.0)
	return_btn.add_theme_stylebox_override("hover", btn_hover)
	
	return_btn.custom_minimum_size = Vector2(350, 65)
	return_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(return_btn)
	
	return_btn.pressed.connect(_on_return_pressed)

func _on_return_pressed():
	if multiplayer.is_server():
		rpc("return_to_lobby")

@rpc("authority", "call_local", "reliable")
func return_to_lobby():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://lobby.tscn")
