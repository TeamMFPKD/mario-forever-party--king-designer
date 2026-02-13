extends Node

signal back_to_title

signal sever_back_to_title
signal client_back_to_title

var multiplayer_manager : MultiplayerManager

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	if multiplayer_manager.is_in_game:
		if multiplayer_manager.multiplayer.is_server():
			multiplayer_manager.restore_origin_player_data()
			multiplayer_manager.players = multiplayer_manager.origin_players.duplicate()
			print("已还原本局开始前玩家列表：")
			print(multiplayer_manager.players)
			emit_signal("sever_back_to_title")
		else:
			# 比主机更早返回标题画面的玩家，需要更新玩家列表
			emit_signal("client_back_to_title")
			emit_signal("players_updated")
		multiplayer_manager.is_in_game = false
		multiplayer_manager.sync_origin_player_data.rpc()
		var fc = func():
			emit_signal("back_to_title")
			print("Player page should be shown now.")
		fc.call_deferred()
