extends Node

# Главный узел мультиплеера WebRTC
var multiplayer_peer = WebRTCMultiplayerPeer.new()
# Словарь для хранения WebRTC соединений с другими игроками
var peers = {} 

@onready var hunter_scene = preload("res://hunter.tscn")
@onready var prop_scene = preload("res://prop.tscn")

func _ready():
	# Подключаем сигналы: когда кто-то зашел или вышел
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# МАГИЯ: Выставляем этот скрипт "наружу", чтобы твой файл js/main.js мог им управлять!
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").godotNetwork = self

# --- ФУНКЦИИ ДЛЯ ВЫЗОВА ИЗ БРАУЗЕРА (js/main.js) ---

func start_host():
	multiplayer_peer.create_server()
	multiplayer.multiplayer_peer = multiplayer_peer
	spawn_player(1, true) # Хост всегда имеет ID = 1. Он будет Охотником.
	print("Godot: Хост запущен (Охотник)!")

func start_client(my_id: int):
	multiplayer_peer.create_client(my_id)
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Godot: Клиент запущен (Проп) с ID ", my_id)

func create_peer(id: int):
	var peer = WebRTCPeerConnection.new()
	# Подключаемся к бесплатному STUN серверу Google для поиска друг друга в интернете
	peer.initialize({ "iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
	
	# Сигналы Godot отправляют данные для Firebase в браузер (в JS)
	peer.session_description_created.connect(self._create_offer_or_answer.bind(id))
	peer.ice_candidate_created.connect(self._new_ice_candidate.bind(id))
	
	multiplayer_peer.add_peer(peer, id)
	peers[id] = peer
	
	if multiplayer.is_server():
		peer.create_offer()

# --- ВНУТРЕННИЕ WebRTC ФУНКЦИИ ---

func _create_offer_or_answer(type: String, sdp: String, id: int):
	peers[id].set_local_description(type, sdp)
	# Отправляем зашифрованные данные о подключении в твой JS
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").sendSDPToFirebase(id, type, sdp)

func _new_ice_candidate(media: String, index: int, name: String, id: int):
	# Отправляем IP-адреса в твой JS
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").sendICEToFirebase(id, media, index, name)

# Эти функции твой JS будет вызывать, когда получит данные из Firebase от других игроков
func set_remote_sdp(id: int, type: String, sdp: String):
	if peers.has(id):
		peers[id].set_remote_description(type, sdp)

func add_remote_ice(id: int, media: String, index: int, name: String):
	if peers.has(id):
		peers[id].add_ice_candidate(media, index, name)

# --- ИГРОВАЯ ЛОГИКА ---

func _on_peer_connected(id):
	print("Godot: Игрок присоединился по WebRTC: ", id)
	if multiplayer.is_server():
		# Хост автоматически спавнит Пропа для нового игрока
		spawn_player(id, false)

func _on_peer_disconnected(id):
	print("Godot: Игрок отключился: ", id)
	if peers.has(id):
		peers.erase(id)
	var level = get_node_or_null("/root/Level")
	if level and level.has_node(str(id)):
		level.get_node(str(id)).queue_free()

func spawn_player(id: int, is_hunter: bool):
	var level = get_node_or_null("/root/Level")
	if not level: return
	
	var player = hunter_scene.instantiate() if is_hunter else prop_scene.instantiate()
	
	# ИМЯ УЗЛА ОБЯЗАТЕЛЬНО ДОЛЖНО БЫТЬ ID ИГРОКА! Иначе синхронизация не поймет, кто есть кто.
	player.name = str(id)
	level.add_child(player)
