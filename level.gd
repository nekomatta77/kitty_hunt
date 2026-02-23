extends Node3D

var time_left: float = 300.0 
var game_active: bool = false
var _sync_timer: float = 0.0 

var ui_layer: CanvasLayer
var timer_label: Label
var game_over_overlay: ColorRect
var game_over_panel: Panel
var result_label: Label
var return_btn: Button
var modern_font: SystemFont

# Массив для отслеживания загрузившихся игроков
var loaded_peers = []

func _ready():
	# ФУНДАМЕНТАЛЬНЫЙ ФИКС: Жестко задаем имя сцены. 
	# Теперь сетевые пути (/root/Level/...) у хоста и клиента будут совпадать на 100%
	name = "Level"
	
	modern_font = SystemFont.new()
	modern_font.font_names = PackedStringArray(["Montserrat", "Segoe UI", "Roboto", "sans-serif"])
	modern_font.font_weight = 700
	
	setup_ui()
	call_deferred("_notify_loaded")

# СИСТЕМА РУКОПОЖАТИЯ: Игрок загрузился и сообщает об этом серверу
func _notify_loaded():
	print("[Level] Сцена загружена локально. Ждем остальных...")
	if Network.is_network_active:
		var my_id = multiplayer.get_unique_id()
		register_player_loaded.rpc_id(1, my_id)
	else:
		_spawn_all()
		start_game()

# Сервер собирает "галочки" готовности со всех игроков
@rpc("any_peer", "call_local", "reliable")
func register_player_loaded(peer_id: int):
	if multiplayer.is_server():
		print("[Level] Игрок ", peer_id, " прогрузил 3D карту.")
		if not loaded_peers.has(peer_id):
			loaded_peers.append(peer_id)
		
		var expected_players = multiplayer.get_peers().size() + 1
		if loaded_peers.size() >= expected_players:
			print("[Level] ВСЕ ИГРОКИ НА КАРТЕ! Запускаем спавн.")
			do_spawn_and_start.rpc()

# Сервер дает отмашку на одновременный спавн
@rpc("authority", "call_local", "reliable")
func do_spawn_and_start():
	print("[Level] Получена команда на спавн от сервера!")
	_spawn_all()
	if multiplayer.is_server() or not Network.is_network_active:
		start_game()

func _spawn_all():
	var my_id = multiplayer.get_unique_id() if Network.is_network_active else 1
	Network.spawn_player_locally(my_id, my_id == 1)
	
	if Network.is_network_active:
		for id in multiplayer.get_peers():
			Network.spawn_player_locally(id, id == 1)

func start_game():
	game_active = true
	print("[Level] Игра началась! Таймер запущен.")
	if Network.is_network_active:
		sync_game_state.rpc(true, 300.0)
	else:
		sync_game_state(true, 300.0)

@rpc("authority", "call_local", "reliable")
func sync_game_state(active: bool, time: float):
	game_active = active
	time_left = time

func _process(delta):
	if not game_active: return
	
	time_left -= delta
	
	if multiplayer.is_server() or not Network.is_network_active:
		if time_left <= 0:
			time_left = 0
			game_active = false 
			if Network.is_network_active:
				show_game_over.rpc(false) 
			else:
				show_game_over(false)
		else:
			if Network.is_network_active:
				_sync_timer += delta
				if _sync_timer >= 2.0:
					sync_time.rpc(time_left)
					_sync_timer = 0.0

	update_timer_ui()

@rpc("authority", "call_remote", "unreliable")
func sync_time(time: float):
	time_left = time

func update_timer_ui():
	if not is_instance_valid(timer_label): return
	var mins = int(max(time_left, 0)) / 60
	var secs = int(max(time_left, 0)) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	
	if time_left <= 60:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 1, 1))

func check_hunter_win(dying_node = null):
	if not game_active or (Network.is_network_active and not multiplayer.is_server()): return
	
	var alive_props = 0
	for prop in get_tree().get_nodes_in_group("player_props"):
		if prop != dying_node and is_instance_valid(prop) and not prop.is_queued_for_deletion():
			alive_props += 1
			
	if alive_props <= 0 and game_active:
		game_active = false
		if Network.is_network_active:
			show_game_over.rpc(true)
		else:
			show_game_over(true)

func check_prop_win(dying_node = null):
	if not game_active or (Network.is_network_active and not multiplayer.is_server()): return
	
	var alive_hunters = 0
	for hunter in get_tree().get_nodes_in_group("player_hunters"):
		if hunter != dying_node and is_instance_valid(hunter) and not hunter.is_queued_for_deletion():
			alive_hunters += 1
			
	if alive_hunters <= 0 and game_active:
		game_active = false
		if Network.is_network_active:
			show_game_over.rpc(false)
		else:
			show_game_over(false)

# ФИКС МЫШИ ДЛЯ МОБИЛОК (Защита от SecurityError)
func safe_unlock_mouse():
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if not is_mobile:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

@rpc("authority", "call_local", "reliable")
func show_game_over(hunter_won: bool):
	game_active = false
	safe_unlock_mouse()
	
	if is_instance_valid(timer_label): timer_label.hide()
	if is_instance_valid(game_over_overlay): game_over_overlay.show()
	
	if is_instance_valid(game_over_panel):
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
		
	if not Network.is_network_active or multiplayer.is_server():
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
	if Network.is_network_active and multiplayer.is_server():
		return_to_lobby.rpc()
	elif not Network.is_network_active:
		return_to_lobby()

@rpc("authority", "call_local", "reliable")
func return_to_lobby():
	safe_unlock_mouse()
	get_tree().call_deferred("change_scene_to_file", "res://lobby.tscn")
