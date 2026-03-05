extends Node

var multiplayer_manager : MultiplayerManager

var saved_player_level_data = []

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager

# 将非空关卡数据缓存到本地
func _process(_delta):
	if not multiplayer_manager:
		return

	for player in multiplayer_manager.players:
		if saved_player_level_data.has(player):
			continue
		if player.level_file_name != "invalid":
			saved_player_level_data.append(player)
			# 缓存非空关卡数据
			var file = FileAccess.open(player.level_file_name, FileAccess.WRITE)
			file.store_string(player.level_data)
			print("[%s] 玩家 " % Time.get_time_string_from_system(), player.name, " 的关卡 ", player.level_file_name, " 的数据：", player.level_data)
			file.close()
			print("[%s] 玩家 " % Time.get_time_string_from_system(), player.name, " 的关卡数据已缓存到本地")
			print("[%s] 关卡预览：" % Time.get_time_string_from_system(), player.level_data)
