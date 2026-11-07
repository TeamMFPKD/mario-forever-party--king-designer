extends Node

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = MPManager

func lets_play_together() -> void:
	Log.i("lets_play_together.gd", "Lets play together")
	var levels: Array = []
	for player: Variant in multiplayer_manager.players:
		if player.level_data == "invalid":
			push_error("Player " + str(player.name) + " has no level data")
			var player_id: int = player.id
			multiplayer_manager._on_peer_disconnected(player_id)
		else:
			levels.append(player.level_file_name)
	
	# 随机选择功能
	var random_levels: Array = levels.duplicate()
	random_levels.shuffle()
	
	# 显示编号结果
	Log.i("lets_play_together.gd", "随机选择结果：")
	for i: int in range(random_levels.size()):
		Log.i("lets_play_together.gd", ["", str(i) + " " + str(random_levels[i])])
	
	multiplayer_manager.lets_play_together.rpc(random_levels)