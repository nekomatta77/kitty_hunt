extends Node3D

var time_left: float = 300.0 # 5 минут = 300 секунд
var game_active: bool = false

# UI Элементы, которые мы создаем скриптом
var ui_layer: CanvasLayer
var timer_label: Label
var game_over_panel: Panel
var result_label: Label
var return_btn: Button

func _ready():
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
		
		# Победа пропов по таймеру
		if time_left <= 0:
			time_left = 0
			rpc("show_game_over", false) 
		else:
			# Хост синхронизирует время для клиентов (не каждый кадр, а плавно)
			rpc("sync_time", time_left)

	update_timer_ui()

@rpc("authority", "call_remote", "unreliable")
func sync_time(time: float):
	time_left = time

func update_timer_ui():
	if not timer_label: return
	var mins = int(time_left) / 60
	var secs = int(time_left) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	
	# Краснеет на последней минуте
	if time_left <= 60:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 1, 1))

# Вызывается хостом, когда умирает любой проп
func check_hunter_win():
	if not game_active or not multiplayer.is_server(): return
	
	var alive_props = 0
	for child in get_children():
		if child.is_in_group("props") and not child.is_queued_for_deletion():
			alive_props += 1
			
	if alive_props <= 0:
		rpc("show_game_over", true) # Победа Охотника

@rpc("authority", "call_local", "reliable")
func show_game_over(hunter_won: bool):
	game_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Обязательно освобождаем мышку
	
	timer_label.hide()
	game_over_panel.show()
	
	if hunter_won:
		result_label.text = "ПОБЕДА ОХОТНИКА!\n\nВсе пропы уничтожены"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	else:
		result_label.text = "ПОБЕДА ПРОПОВ!\n\nОхотник не справился"
		result_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
		
	if multiplayer.is_server():
		return_btn.show() # Кнопка только у хоста
	else:
		return_btn.hide()
		# Добавляем надпись для клиентов
		var wait_lbl = Label.new()
		wait_lbl.text = "Ожидание действий хоста..."
		wait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wait_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		wait_lbl.position.y -= 25
		game_over_panel.add_child(wait_lbl)

# --- ГЕНЕРАЦИЯ ЭСТЕТИЧНОГО ИНТЕРФЕЙСА ЧЕРЕЗ КОД ---
func setup_ui():
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# === ТАЙМЕР ===
	timer_label = Label.new()
	timer_label.text = "05:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 54)
	timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	timer_label.add_theme_constant_override("shadow_offset_x", 2)
	timer_label.add_theme_constant_override("shadow_offset_y", 2)
	ui_layer.add_child(timer_label)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	timer_label.position.y += 20
	
	# === ОКНО ПОБЕДЫ ===
	game_over_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.9) # Темно-синий фон
	style.set_corner_radius_all(20)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.2)
	game_over_panel.add_theme_stylebox_override("panel", style)
	
	ui_layer.add_child(game_over_panel)
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game_over_panel.custom_minimum_size = Vector2(450, 300)
	game_over_panel.position -= Vector2(225, 150) # Математический центр
	game_over_panel.hide()
	
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 30)
	result_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	game_over_panel.add_child(result_label)
	result_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	result_label.position.y += 40
	
	return_btn = Button.new()
	return_btn.text = "Вернуться в лобби"
	return_btn.add_theme_font_size_override("font_size", 22)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.8, 1)
	btn_style.set_corner_radius_all(10)
	return_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.3, 0.6, 0.9, 1)
	return_btn.add_theme_stylebox_override("hover", btn_hover)
	
	game_over_panel.add_child(return_btn)
	return_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	return_btn.custom_minimum_size = Vector2(300, 60)
	return_btn.position.y -= 90
	return_btn.position.x += 75
	return_btn.pressed.connect(_on_return_pressed)

func _on_return_pressed():
	if multiplayer.is_server():
		rpc("return_to_lobby")

@rpc("authority", "call_local", "reliable")
func return_to_lobby():
	# Очищаем уровень и возвращаемся в лобби (сеть останется подключенной)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://lobby.tscn")
