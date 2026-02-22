extends Control

# Ссылки на элементы UI
var player_list_container: VBoxContainer
var map_select: OptionButton
var ready_button: Button
var status_label: Label
var main_panel: PanelContainer
var ready_overlay: ColorRect # Тот самый полноэкранный экран готовности

# Словарь для хранения статуса "Готов" каждого игрока (ID -> bool)
var ready_states = {} 

func _ready():
	_build_ui()
	
	# Подключаем сигналы сети для мгновенного реагирования
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	get_tree().root.size_changed.connect(_update_ui_size)
	_update_ui_size()
	
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(refresh_players)
	add_child(timer)

# ==========================================
# ПОСТРОЕНИЕ UI (С ОВЕРЛЕЕМ ГОТОВНОСТИ)
# ==========================================
func _build_ui():
	for child in get_children():
		child.queue_free()
		
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.12, 0.15)
	add_child(bg)
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center_container)
	
	main_panel = PanelContainer.new()
	center_container.add_child(main_panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.18, 0.22)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.3, 0.3, 0.4)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 10
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	main_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "KITTY HUNT: ЛОББИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(title)
	
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(status_label)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var list_bg = PanelContainer.new()
	var list_style = StyleBoxFlat.new()
	list_style.bg_color = Color(0.1, 0.1, 0.12)
	list_style.corner_radius_top_left = 8
	list_style.corner_radius_top_right = 8
	list_style.corner_radius_bottom_left = 8
	list_style.corner_radius_bottom_right = 8
	list_bg.add_theme_stylebox_override("panel", list_style)
	list_bg.size_flags_horizontal = SIZE_EXPAND_FILL
	list_bg.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.add_child(list_bg)
	
	var list_margin = MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	list_margin.add_theme_constant_override("margin_top", 12)
	list_margin.add_theme_constant_override("margin_bottom", 12)
	list_bg.add_child(list_margin)
	
	player_list_container = VBoxContainer.new()
	player_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	list_margin.add_child(player_list_container)
	
	var map_label = Label.new()
	map_label.text = "Локация (выбирает Хост):"
	map_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(map_label)
	
	map_select = OptionButton.new()
	map_select.add_item("Базовая Арена")
	map_select.add_item("Склад (В разработке)")
	map_select.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(map_select)
	
	# Теперь это кнопка ГОТОВНОСТИ для всех
	ready_button = Button.new()
	ready_button.text = "ГОТОВ"
	ready_button.custom_minimum_size = Vector2(0, 55)
	ready_button.add_theme_font_size_override("font_size", 18)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.65, 0.35)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	ready_button.add_theme_stylebox_override("normal", btn_style)
	ready_button.pressed.connect(_on_ready_pressed)
	vbox.add_child(ready_button)
	
	# ==========================================
	# ПОЛНОЭКРАННЫЙ ОВЕРЛЕЙ "ВЫ ГОТОВЫ"
	# ==========================================
	ready_overlay = ColorRect.new()
	ready_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ready_overlay.color = Color(0.1, 0.7, 0.3, 0.95) # Полупрозрачный зеленый
	ready_overlay.hide() # Скрыт по умолчанию
	add_child(ready_overlay)
	
	var overlay_center = CenterContainer.new()
	overlay_center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ready_overlay.add_child(overlay_center)
	
	var overlay_vbox = VBoxContainer.new()
	overlay_vbox.add_theme_constant_override("separation", 30)
	overlay_center.add_child(overlay_vbox)
	
	var overlay_text = Label.new()
	overlay_text.text = "ВЫ ГОТОВЫ!\nОжидание остальных игроков..."
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_text.add_theme_font_size_override("font_size", 32)
	overlay_text.add_theme_color_override("font_color", Color.WHITE)
	overlay_vbox.add_child(overlay_text)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "ОТМЕНИТЬ"
	cancel_btn.custom_minimum_size = Vector2(200, 50)
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.8, 0.2, 0.2) # Красная кнопка отмены
	cancel_style.corner_radius_top_left = 8
	cancel_style.corner_radius_top_right = 8
	cancel_style.corner_radius_bottom_left = 8
	cancel_style.corner_radius_bottom_right = 8
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.pressed.connect(_on_ready_pressed) # Нажатие вызывает ту же функцию (переключатель)
	overlay_vbox.add_child(cancel_btn)

func _update_ui_size():
	if not is_instance_valid(main_panel): return
	var screen_size = get_viewport_rect().size
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or screen_size.x < 700
	
	if is_mobile or screen_size.x < screen_size.y:
		main_panel.custom_minimum_size = Vector2(screen_size.x * 0.9, screen_size.y * 0.9)
	else:
		main_panel.custom_minimum_size = Vector2(450, 550)

# ==========================================
# ЛОГИКА И СЕТЬ
# ==========================================

# Когда новый игрок подключается, хост отправляет ему текущие статусы
func _on_peer_connected(id: int):
	if multiplayer.is_server():
		for peer_id in ready_states:
			if ready_states[peer_id]:
				set_player_ready.rpc_id(id, peer_id, true)
	refresh_players()

func _on_peer_disconnected(id: int):
	ready_states.erase(id)
	refresh_players()
	if multiplayer.is_server():
		_check_all_ready() # Проверяем, может оставшиеся уже все готовы

func refresh_players():
	for child in player_list_container.get_children():
		child.queue_free()
		
	var is_host = multiplayer.is_server()
	var my_id = multiplayer.get_unique_id()
	
	map_select.disabled = not is_host
	status_label.text = "Ваша роль: Хост (Охотник)" if is_host else "Ваша роль: Проп"

	# 🔥 ИЗМЕНЕНО: Теперь берем НАШ реальный ник из скрипта Network
	var display_my_name = Network.my_name + " (Вы)"
	_add_player_ui(display_my_name, is_host, ready_states.get(my_id, false))
	
	for peer in multiplayer.get_peers():
		var peer_is_host = (peer == 1)
		# 🔥 ИЗМЕНЕНО: Берем чужой ник из словаря, если его еще нет - пишем "Игрок [ID]"
		var peer_name = Network.player_names.get(peer, "Ожидание ника...")
		_add_player_ui(peer_name, peer_is_host, ready_states.get(peer, false))

func _add_player_ui(p_name: String, is_host: bool, is_ready: bool):
	var hbox = HBoxContainer.new()
	
	var icon = Panel.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(1, 0.3, 0.3) if is_host else Color(0.3, 0.6, 1)
	icon_style.corner_radius_top_left = 4
	icon_style.corner_radius_top_right = 4
	icon_style.corner_radius_bottom_left = 4
	icon_style.corner_radius_bottom_right = 4
	icon.add_theme_stylebox_override("panel", icon_style)
	
	var lbl = Label.new()
	var status_text = " [ГОТОВ]" if is_ready else " [НЕ ГОТОВ]"
	lbl.text = p_name + (" - Охотник" if is_host else " - Проп") + status_text
	
	# Подсвечиваем текст зеленым, если игрок готов
	if is_ready:
		lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	hbox.add_child(icon)
	hbox.add_child(lbl)
	player_list_container.add_child(hbox)

# ==========================================
# СИСТЕМА ГОТОВНОСТИ (READY SYSTEM)
# ==========================================

func _on_ready_pressed():
	var my_id = multiplayer.get_unique_id()
	var current_state = ready_states.get(my_id, false)
	# Меняем статус на противоположный и отправляем ВСЕМ (включая себя)
	set_player_ready.rpc(my_id, not current_state)

# Эта функция вызывается у ВСЕХ игроков по сети
@rpc("any_peer", "call_local", "reliable")
func set_player_ready(id: int, is_ready: bool):
	ready_states[id] = is_ready
	refresh_players()
	
	# Если это мы поменяли статус - показываем или скрываем полноэкранный зеленый оверлей
	if id == multiplayer.get_unique_id():
		if is_ready:
			ready_overlay.show()
		else:
			ready_overlay.hide()
			
	# Хост проверяет, все ли нажали "Готов"
	if multiplayer.is_server():
		_check_all_ready()

# Проверка, которую делает ТОЛЬКО сервер
func _check_all_ready():
	var peers = multiplayer.get_peers()
	# Если кроме хоста никого нет, игру не запускаем (защита от соло-старта)
	if peers.size() == 0: 
		return 
		
	var all_ready = ready_states.get(1, false) # Готов ли сам хост?
	for peer in peers:
		if not ready_states.get(peer, false): # Если хоть один не готов
			all_ready = false
			break
			
	# Если все готовы — сервер командует начать игру!
	if all_ready:
		start_game_for_all.rpc(map_select.selected)

@rpc("authority", "call_local", "reliable")
func start_game_for_all(map_index: int):
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { document.documentElement.requestFullscreen(); } catch(e) {}")
	get_tree().change_scene_to_file("res://level.tscn")
