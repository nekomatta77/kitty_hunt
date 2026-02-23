extends Node

var multiplayer_peer = WebRTCMultiplayerPeer.new()
var peers = {} 
var my_name = "Игрок"

var is_network_active = false
var is_host_mode = false

var player_data: Dictionary = {}

signal lobby_updated

@onready var hunter_scene = preload("res://hunter.tscn")
@onready var prop_scene = preload("res://prop.tscn")

var cb_start_host; var cb_start_client; var cb_create_peer
var cb_set_remote_sdp; var cb_add_remote_ice

func _ready():
	print("[Network] Инициализация Network.gd")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if OS.has_feature("web"):
		var js_code = """
			(function() {
				var params = new URLSearchParams(window.location.search);
				var user = params.get('user');
				if (user) return decodeURIComponent(user);
				if (window.playerName) return window.playerName;
				return null;
			})();
		"""
		var fetched_name = JavaScriptBridge.eval(js_code)
		if fetched_name and str(fetched_name).strip_edges() != "" and str(fetched_name) != "null":
			my_name = str(fetched_name)
		else:
			my_name = "Игрок " + str(randi() % 999)
			
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
		win.godotNetworkReady = true 
	else:
		my_name = "Игрок " + str(randi() % 999)

func _js_start_host(args): start_host()
func _js_start_client(args): start_client(int(args[0]))
func _js_create_peer(args): create_peer(int(args[0]))
func _js_set_remote_sdp(args): set_remote_sdp(int(args[0]), str(args[1]), str(args[2]))
func _js_add_remote_ice(args): add_remote_ice(int(args[0]), str(args[1]), int(args[2]), str(args[3]))

func start_host():
	print("[Network] Создание хоста...")
	multiplayer_peer.create_server()
	multiplayer.multiplayer_peer = multiplayer_peer
	
	is_network_active = true
	is_host_mode = true
	
	player_data.clear()
	player_data[1] = {"name": my_name, "is_host": true, "is_ready": false}
	lobby_updated.emit()

func start_client(my_id: int):
	print("[Network] Создание клиента с ID: ", my_id)
	multiplayer_peer.create_client(my_id)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	is_network_active = true
	is_host_mode = false
	
	player_data.clear()
	player_data[my_id] = {"name": my_name, "is_host": false, "is_ready": false}
	lobby_updated.emit()

func create_peer(id: int):
	if peers.has(id): return 
	var peer = WebRTCPeerConnection.new()
	peer.initialize({ "iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
	peer.session_description_created.connect(self._create_offer_or_answer.bind(id))
	peer.ice_candidate_created.connect(self._new_ice_candidate.bind(id))
	multiplayer_peer.add_peer(peer, id)
	peers[id] = peer
	
	var my_id = multiplayer.get_unique_id() if is_network_active else 1
	if is_host_mode or (not is_host_mode and my_id > id and id != 1):
		peer.create_offer()

func _create_offer_or_answer(type: String, sdp: String, id: int):
	peers[id].set_local_description(type, sdp)
	if OS.has_feature("web"): 
		JavaScriptBridge.get_interface("window").sendSDPToFirebase(id, type, sdp)

func _new_ice_candidate(media: String, index: int, name: String, id: int):
	if OS.has_feature("web"): 
		JavaScriptBridge.get_interface("window").sendICEToFirebase(id, media, index, name)

func set_remote_sdp(id: int, type: String, sdp: String):
	if not peers.has(id): create_peer(id)
	if peers.has(id): peers[id].set_remote_description(type, sdp)

func add_remote_ice(id: int, media: String, index: int, name: String):
	if not peers.has(id): create_peer(id)
	if peers.has(id): peers[id].add_ice_candidate(media, index, name)

func _on_peer_connected(id):
	print("[Network] ПИР ПОДКЛЮЧЕН! ID: ", id)
	if is_host_mode: 
		sync_lobby_state.rpc_id(id, player_data)
	else:
		if id == 1:
			await get_tree().create_timer(0.2).timeout
			register_client.rpc_id(1, my_name)

@rpc("any_peer", "call_remote", "reliable")
func register_client(nickname: String):
	if is_host_mode:
		var sender_id = multiplayer.get_remote_sender_id()
		print("[Network] Регистрация клиента ID: ", sender_id, " Имя: ", nickname)
		player_data[sender_id] = {"name": nickname, "is_host": false, "is_ready": false}
		_broadcast_state()

@rpc("any_peer", "call_remote", "reliable")
func request_ready_toggle():
	if is_host_mode:
		var sender_id = multiplayer.get_remote_sender_id()
		if player_data.has(sender_id):
			player_data[sender_id].is_ready = not player_data[sender_id].is_ready
			print("[Network] Клиент ", sender_id, " изменил готовность: ", player_data[sender_id].is_ready)
			_broadcast_state()

func toggle_host_ready():
	if is_host_mode and player_data.has(1):
		player_data[1].is_ready = not player_data[1].is_ready
		print("[Network] Хост изменил готовность: ", player_data[1].is_ready)
		_broadcast_state()

func _broadcast_state():
	if is_host_mode:
		sync_lobby_state.rpc(player_data)
		lobby_updated.emit() 

@rpc("authority", "call_remote", "reliable")
func sync_lobby_state(server_data: Dictionary):
	print("[Network] Получена синхронизация лобби от сервера.")
	var my_id = multiplayer.get_unique_id() if is_network_active else 1
	var my_local_data = player_data.get(my_id, {"name": my_name, "is_host": false, "is_ready": false})
	
	player_data.clear()
	
	for k in server_data:
		var id = int(k)
		player_data[id] = {
			"name": server_data[k].name,
			"is_host": server_data[k].is_host,
			"is_ready": server_data[k].is_ready
		}
		
	if not is_host_mode and not player_data.has(my_id):
		player_data[my_id] = my_local_data
		
	lobby_updated.emit()

func _on_peer_disconnected(id):
	print("[Network] ПИР ОТКЛЮЧЕН. ID: ", id)
	if peers.has(id): peers.erase(id)
	if player_data.has(id): player_data.erase(id)
	
	var level = get_tree().current_scene
	if level and level.has_node(str(id)):
		var player_node = level.get_node(str(id))
		if is_host_mode:
			if player_node.is_in_group("player_props") and level.has_method("check_hunter_win"):
				level.check_hunter_win(player_node)
			if player_node.is_in_group("player_hunters") and level.has_method("check_prop_win"):
				level.check_prop_win(player_node)
		player_node.queue_free()
		
	if is_host_mode:
		_broadcast_state()
	lobby_updated.emit()

func spawn_player_locally(id: int, is_hunter: bool):
	var level = get_tree().current_scene
	
	# ФУНДАМЕНТАЛЬНЫЙ ФИКС: Гарантируем, что игроки добавляются ТОЛЬКО в корень с именем "Level".
	if level:
		level.name = "Level" 
		
	if not level or not level.has_method("check_hunter_win") or level.has_node(str(id)): 
		return 
	
	print("[Network] Спавн игрока на карте. ID: ", id, " Охотник: ", is_hunter)
	var player = hunter_scene.instantiate() if is_hunter else prop_scene.instantiate()
	player.name = str(id)
	player.add_to_group("player_hunters" if is_hunter else "player_props")
	
	var spawn_x = float(id % 3) * 3.0 - 3.0
	var spawn_z = float((id * 2) % 3) * 3.0 - 3.0
	player.position = Vector3(spawn_x, 5.0, spawn_z)
	level.add_child(player)	
