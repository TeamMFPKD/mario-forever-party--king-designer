extends Node

var multiplayer_manager : MultiplayerManager

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager

func lets_play_together():
	print("[%s] Lets play together" % Time.get_time_string_from_system())
	var levels = []
	for player in multiplayer_manager.players:
		if player.level_data == "invalid":
			push_error("Player " + str(player.name) + " has no level data")
			multiplayer_manager._on_peer_disconnected(player.id)
		else:
			levels.append(player.level_file_name)
	
	# 随机选择功能
	var random_levels = levels.duplicate()
	random_levels.shuffle()
	
	# 显示编号结果
	print("[%s] 随机选择结果：" % Time.get_time_string_from_system())
	for i in range(random_levels.size()):
		print("[%s] " % Time.get_time_string_from_system(), str(i) + " " + random_levels[i])
	
	multiplayer_manager.lets_play_together.rpc(random_levels)