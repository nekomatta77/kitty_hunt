extends Node3D

func _ready():
	# Спавном управляет только сервер (Хост)
	if multiplayer.is_server():
		# 1. Спавним самого хоста (Охотника)
		Network.spawn_player_locally(1, true)
		
		# 2. Спавним всех пропов, которые ждали в лобби
		for id in Network.player_roles:
			if id != 1:
				Network.spawn_player_locally(id, false) # У себя на компе
				Network.rpc("remote_spawn_player", id, false) # Команда всем клиентам заспавнить этого пропа
				Network.rpc_id(id, "remote_spawn_player", 1, true) # Говорим новому пропу заспавнить Охотника
