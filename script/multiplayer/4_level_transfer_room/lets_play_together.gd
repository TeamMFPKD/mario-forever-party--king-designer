extends Node

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager

func lets_play_together() -> void:
	print("[%s] [lets_play_together.gd] Lets play together" % Time.get_time_string_from_system())
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
	print("[%s] [lets_play_together.gd] 随机选择结果：" % Time.get_time_string_from_system())
	for i: int in range(random_levels.size()):
		print("[%s] [lets_play_together.gd] " % Time.get_time_string_from_system(), str(i) + " " + str(random_levels[i]))
	
	multiplayer_manager.lets_play_together.rpc(random_levels)