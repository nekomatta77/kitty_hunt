extends Control

var player_list_container: VBoxContainer
var map_select: OptionButton
var ready_button: Button
var status_label: Label
var main_panel: PanelContainer
var ready_overlay: ColorRect 
var modern_font: SystemFont

var ready_states = {} 

func _ready():
	modern_font = SystemFont.new()
	modern_font.font_names = PackedStringArray(["Montserrat", "Segoe UI", "Roboto", "Helvetica", "sans-serif"])
	modern_font.font_weight = 700
	
	_build_ui()
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	get_tree().root.size_changed.connect(_update_ui_size)
	_update_ui_size()
	
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(refresh_players)
	add_child(timer)

func _build_ui():
	for child in get_children():
		child.queue_free()
		
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center_container)
	
	main_panel = PanelContainer.new()
	center_container.add_child(main_panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	panel_style.set_corner_radius_all(24)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.3, 0.3, 0.4, 0.5)
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 25
	panel_style.shadow_offset = Vector2(0, 10)
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	main_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "KITTY HUNT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", modern_font)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title.add_theme_color_override("font_shadow_color", Color(1, 0.5, 0, 0.4))
	title.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(title)
	
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", modern_font)
	status_label.modulate = Color(0.7, 0.8, 0.9)
	vbox.add_child(status_label)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var list_bg = PanelContainer.new()
	var list_style = StyleBoxFlat.new()
	list_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
	list_style.set_corner_radius_all(16)
	list_bg.add_theme_stylebox_override("panel", list_style)
	list_bg.size_flags_horizontal = SIZE_EXPAND_FILL
	list_bg.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.add_child(list_bg)
	
	var list_margin = MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 16)
	list_margin.add_theme_constant_override("margin_right", 16)
	list_margin.add_theme_constant_override("margin_top", 16)
	list_margin.add_theme_constant_override("margin_bottom", 16)
	list_bg.add_child(list_margin)
	
	player_list_container = VBoxContainer.new()
	player_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	player_list_container.add_theme_constant_override("separation", 10)
	list_margin.add_child(player_list_container)
	
	map_select = OptionButton.new()
	map_select.add_theme_font_override("font", modern_font)
	map_select.add_item("Базовая Арена")
	map_select.add_item("Склад (В разработке)")
	map_select.custom_minimum_size = Vector2(0, 45)
	vbox.add_child(map_select)
	
	ready_button = Button.new()
	ready_button.text = "ГОТОВ"
	ready_button.add_theme_font_override("font", modern_font)
	ready_button.custom_minimum_size = Vector2(0, 60)
	ready_button.add_theme_font_size_override("font_size", 22)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.75, 0.45)
	btn_style.set_corner_radius_all(12)
	btn_style.shadow_color = Color(0.1, 0.5, 0.2, 0.5)
	btn_style.shadow_size = 8
	btn_style.shadow_offset = Vector2(0, 4)
	ready_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.3, 0.85, 0.5)
	ready_button.add_theme_stylebox_override("hover", btn_hover)
	
	ready_button.pressed.connect(_on_ready_pressed)
	vbox.add_child(ready_button)
	
	ready_overlay = ColorRect.new()
	ready_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ready_overlay.color = Color(0.05, 0.5, 0.25, 0.9)
	ready_overlay.hide() 
	add_child(ready_overlay)
	
	var overlay_center = CenterContainer.new()
	overlay_center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ready_overlay.add_child(overlay_center)
	
	var overlay_vbox = VBoxContainer.new()
	overlay_vbox.add_theme_constant_override("separation", 30)
	overlay_center.add_child(overlay_vbox)
	
	var overlay_text = Label.new()
	overlay_text.text = "ВЫ ГОТОВЫ!\nОжидание остальных..."
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_text.add_theme_font_override("font", modern_font)
	overlay_text.add_theme_font_size_override("font_size", 38)
	overlay_text.add_theme_color_override("font_color", Color.WHITE)
	overlay_vbox.add_child(overlay_text)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "ОТМЕНИТЬ"
	cancel_btn.add_theme_font_override("font", modern_font)
	cancel_btn.custom_minimum_size = Vector2(200, 55)
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.8, 0.25, 0.3) 
	cancel_style.set_corner_radius_all(12)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	
	var cancel_hover = cancel_style.duplicate()
	cancel_hover.bg_color = Color(0.9, 0.35, 0.4)
	cancel_btn.add_theme_stylebox_override("hover", cancel_hover)
	
	cancel_btn.pressed.connect(_on_ready_pressed) 
	overlay_vbox.add_child(cancel_btn)

func _update_ui_size():
	if not is_instance_valid(main_panel): return
	var screen_size = get_viewport_rect().size
	var is_mobile = OS.has_feature("mobile") or screen_size.x < 700
	
	if is_mobile or screen_size.x < screen_size.y:
		main_panel.custom_minimum_size = Vector2(screen_size.x * 0.9, screen_size.y * 0.9)
	else:
		main_panel.custom_minimum_size = Vector2(500, 600)

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
		_check_all_ready()

func refresh_players():
	for child in player_list_container.get_children():
		child.queue_free()
		
	var is_host = multiplayer.is_server()
	var my_id = multiplayer.get_unique_id()
	
	map_select.disabled = not is_host
	status_label.text = "Роль: Охотник (Хост)" if is_host else "Роль: Проп"

	var display_my_name = Network.my_name + " (Вы)"
	_add_player_ui(display_my_name, is_host, ready_states.get(my_id, false))
	
	for peer in multiplayer.get_peers():
		var peer_is_host = (peer == 1)
		var peer_name = Network.player_names.get(peer, "Игрок подключается...")
		_add_player_ui(peer_name, peer_is_host, ready_states.get(peer, false))

func _add_player_ui(p_name: String, is_host: bool, is_ready: bool):
	var panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(1, 1, 1, 0.05)
	p_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", p_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var icon = Panel.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(1, 0.4, 0.4) if is_host else Color(0.4, 0.7, 1)
	icon_style.set_corner_radius_all(10) # Круглая иконка
	icon.add_theme_stylebox_override("panel", icon_style)
	
	var lbl = Label.new()
	lbl.add_theme_font_override("font", modern_font)
	var role_txt = "Охотник" if is_host else "Проп"
	lbl.text = p_name + " [" + role_txt + "]"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var status_lbl = Label.new()
	status_lbl.add_theme_font_override("font", modern_font)
	status_lbl.text = "ГОТОВ" if is_ready else "НЕ ГОТОВ"
	
	if is_ready:
		status_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	hbox.add_child(icon)
	hbox.add_child(lbl)
	hbox.add_child(status_lbl)
	
	player_list_container.add_child(panel)

func _on_ready_pressed():
	var my_id = multiplayer.get_unique_id()
	var current_state = ready_states.get(my_id, false)
	set_player_ready.rpc(my_id, not current_state)

@rpc("any_peer", "call_local", "reliable")
func set_player_ready(id: int, is_ready: bool):
	ready_states[id] = is_ready
	refresh_players()
	
	if id == multiplayer.get_unique_id():
		if is_ready:
			ready_overlay.modulate = Color(1,1,1,0)
			ready_overlay.show()
			var tween = create_tween()
			tween.tween_property(ready_overlay, "modulate", Color(1,1,1,1), 0.3)
		else:
			ready_overlay.hide()
			
	if multiplayer.is_server():
		_check_all_ready()

func _check_all_ready():
	var peers = multiplayer.get_peers()
	if peers.size() == 0: 
		return 
		
	var all_ready = ready_states.get(1, false) 
	for peer in peers:
		if not ready_states.get(peer, false): 
			all_ready = false
			break
			
	if all_ready:
		start_game_for_all.rpc(map_select.selected)

@rpc("authority", "call_local", "reliable")
func start_game_for_all(map_index: int):
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { document.documentElement.requestFullscreen(); } catch(e) {}")
	get_tree().change_scene_to_file("res://level.tscn")
