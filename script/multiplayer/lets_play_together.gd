extends Node

var multiplayer_manager : MultiplayerManager

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager

func lets_play_together():
	print("Lets play together")
	var levels = []
	for player in multiplayer_manager.players:
		levels.append(player.level_file_name)
	
	# 随机选择功能
	var random_levels = levels.duplicate()
	random_levels.shuffle()
	
	# 显示编号结果
	print("随机选择结果：")
	for i in range(random_levels.size()):
		print(str(i) + " " + random_levels[i])
	
	multiplayer_manager.lets_play_together.rpc(random_levels)
	