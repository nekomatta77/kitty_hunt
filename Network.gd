extends Node

var multiplayer_peer = WebRTCMultiplayerPeer.new()
var peers = {} 
var player_roles = {} 

# --- НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ НИКНЕЙМОВ ---
var player_names = {} 
var my_name = "Игрок"

@onready var hunter_scene = preload("res://hunter.tscn")
@onready var prop_scene = preload("res://prop.tscn")

var cb_start_host
var cb_start_client
var cb_create_peer
var cb_set_remote_sdp
var cb_add_remote_ice

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if OS.has_feature("web"):
		cb_start_host = JavaScriptBridge.create_callback(_js_start_host)
		cb_start_client = JavaScriptBridge.create_callback(_js_start_client)
		cb_create_peer = JavaScriptBridge.create_callback(_js_create_peer)
		cb_set_remote_sdp = JavaScriptBridge.create_callback(_js_set_remote_sdp)
		cb_add_remote_ice = JavaScriptBridge.create_callback(_js_add_remote_ice)
		
		var win = JavaScriptBridge.get_interface("window")
		win.godot_start_host = cb_start_host
		win.godot_start_client = cb_start_client
		win.godot_create_peer = cb_create_peer
		win.godot_set_remote_sdp = cb_set_remote_sdp
		win.godot_add_remote_ice = cb_add_remote_ice
		
		# 🔥 ДОБАВЛЕНО: Пытаемся получить никнейм из JS (из LocalStorage проекта neko-board)
		var js_name = JavaScriptBridge.eval("window.localStorage.getItem('username') || window.currentUserName")
		if js_name and typeof(js_name) == TYPE_STRING and js_name != "":
			my_name = js_name
			
		win.godotNetworkReady = true

func _js_start_host(args): start_host()
func _js_start_client(args): start_client(int(args[0]))
func _js_create_peer(args): create_peer(int(args[0]))
func _js_set_remote_sdp(args): set_remote_sdp(int(args[0]), str(args[1]), str(args[2]))
func _js_add_remote_ice(args): add_remote_ice(int(args[0]), str(args[1]), int(args[2]), str(args[3]))

func start_host():
	multiplayer_peer.create_server()
	multiplayer.multiplayer_peer = multiplayer_peer
	player_roles[1] = true 
	print("Godot: Хост запущен (Охотник)!")

func start_client(my_id: int):
	multiplayer_peer.create_client(my_id)
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Godot: Клиент запущен (Проп) с ID ", my_id)
	create_peer(1)

func create_peer(id: int):
	var peer = WebRTCPeerConnection.new()
	peer.initialize({ "iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
	peer.session_description_created.connect(self._create_offer_or_answer.bind(id))
	peer.ice_candidate_created.connect(self._new_ice_candidate.bind(id))
	multiplayer_peer.add_peer(peer, id)
	peers[id] = peer
	if multiplayer.is_server(): peer.create_offer()

func _create_offer_or_answer(type: String, sdp: String, id: int):
	peers[id].set_local_description(type, sdp)
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").sendSDPToFirebase(id, type, sdp)

func _new_ice_candidate(media: String, index: int, name: String, id: int):
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").sendICEToFirebase(id, media, index, name)

func set_remote_sdp(id: int, type: String, sdp: String):
	if peers.has(id): peers[id].set_remote_description(type, sdp)

func add_remote_ice(id: int, media: String, index: int, name: String):
	if peers.has(id): peers[id].add_ice_candidate(media, index, name)

func _on_peer_connected(id):
	print("Godot: Игрок присоединился по WebRTC: ", id)
	if multiplayer.is_server():
		player_roles[id] = false
	
	# 🔥 ДОБАВЛЕНО: При подключении отправляем свой никнейм новому игроку
	register_player_name.rpc_id(id, multiplayer.get_unique_id(), my_name)

# 🔥 ДОБАВЛЕНО: RPC функция для регистрации чужого никнейма
@rpc("any_peer", "call_local", "reliable")
func register_player_name(id: int, p_name: String):
	player_names[id] = p_name
	# Если мы находимся в лобби, принудительно обновляем список
	var lobby = get_node_or_null("/root/Lobby")
	if lobby and lobby.has_method("refresh_players"):
		lobby.refresh_players()

func _on_peer_disconnected(id):
	print("Godot: Игрок отключился: ", id)
	if peers.has(id): peers.erase(id)
	if player_roles.has(id): player_roles.erase(id)
	if player_names.has(id): player_names.erase(id)
	var level = get_node_or_null("/root/Level")
	if level and level.has_node(str(id)):
		level.get_node(str(id)).queue_free()

func spawn_player_locally(id: int, is_hunter: bool):
	var level = get_node_or_null("/root/Level")
	if not level: return
	if level.has_node(str(id)): return 
	
	var player = hunter_scene.instantiate() if is_hunter else prop_scene.instantiate()
	player.name = str(id)
	var random_x = randf_range(-5.0, 5.0)
	var random_z = randf_range(-5.0, 5.0)
	player.position = Vector3(random_x, 5.0, random_z)
	level.add_child(player)

@rpc("authority", "call_remote", "reliable")
func remote_spawn_player(id: int, is_hunter: bool):
	spawn_player_locally(id, is_hunter)
