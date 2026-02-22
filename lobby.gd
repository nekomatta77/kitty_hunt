extends Control

@onready var player_list = $Panel/VBoxContainer/PlayerList
@onready var map_select = $Panel/VBoxContainer/MapSelect
@onready var start_button = $Panel/VBoxContainer/StartButton

func _ready():
	# Обновляем список игроков каждую секунду
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(refresh_players)
	add_child(timer)
	
	# Настраиваем права доступа
	if multiplayer.get_unique_id() == 1: # Если мы Хост
		start_button.show()
		map_select.disabled = false
		map_select.add_item("Базовая Арена")
		map_select.add_item("Склад (В разработке)")
		start_button.pressed.connect(_on_start_pressed)
	else: # Если мы Клиент (Проп)
		start_button.hide()
		map_select.disabled = true
		map_select.add_item("Ожидание хоста...")

func refresh_players():
	player_list.clear()
	var my_id = multiplayer.get_unique_id()
	var my_role = "Охотник (Хост)" if my_id == 1 else "Проп"
	player_list.add_item("Вы (ID: " + str(my_id) + ") - " + my_role)
	
	for peer in multiplayer.get_peers():
		var role = "Охотник (Хост)" if peer == 1 else "Проп"
		player_list.add_item("Игрок " + str(peer) + " - " + role)

func _on_start_pressed():
	# Хост дает команду всем загрузить выбранную карту
	rpc("start_game_for_all", map_select.selected)

@rpc("authority", "call_local", "reliable")
func start_game_for_all(map_index: int):
	# 🔥 МАГИЯ ФУЛЛСКРИНА ДЛЯ СМАРТФОНОВ
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { document.documentElement.requestFullscreen(); } catch(e) {}")
	
	# Меняем сцену лобби на саму игру
	# В будущем тут можно сделать if map_index == 1: load("sklad.tscn")
	get_tree().change_scene_to_file("res://level.tscn")
