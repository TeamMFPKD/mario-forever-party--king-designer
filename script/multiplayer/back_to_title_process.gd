extends Node

signal back_to_title

signal sever_back_to_title
signal client_back_to_title

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = MPManager
	if multiplayer_manager.is_in_game:
		multiplayer_manager.is_in_game = false
		if multiplayer_manager.multiplayer.is_server():
			multiplayer_manager.restore_origin_player_data()
			Log.i("BackToTitleProcessor", "已还原本局开始前玩家列表：")
			multiplayer_manager.print_players()
			emit_signal("sever_back_to_title")
			multiplayer_manager.sync_origin_player_data.rpc()
		else:
			# 比主机更早返回标题画面的玩家，需要更新玩家列表
			emit_signal("client_back_to_title")
			multiplayer_manager.emit_signal("players_updated")
		multiplayer_manager.is_in_game = false
		var fc: Callable = func() -> void:
			emit_signal("back_to_title")
			Log.i("BackToTitleProcessor", "Player page should be shown now.")
		fc.call_deferred()