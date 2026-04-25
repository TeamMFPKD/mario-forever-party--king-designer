extends Node

var multiplayer_manager : MultiplayerManager

var saved_player_id = []

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.players_updated.connect(self._players_updated)

# 将非空关卡数据缓存到本地
func _players_updated():
	if not multiplayer_manager:
		return
	for player in multiplayer_manager.players:
		if saved_player_id.has(player.id) or player.level_data == "invalid" or player.level_data.is_empty() or player.level_file_name == "invalid":
			continue
		saved_player_id.append(player.id)
		# 缓存非空关卡数据，使用原子写入保护
		var tmp_file_name = player.level_file_name + ".tmp"
		var file = FileAccess.open(tmp_file_name, FileAccess.WRITE)
		if not file:
			var err = FileAccess.get_open_error()
			push_error("[%s] 无法打开文件写入：%s, error: %d" % [Time.get_time_string_from_system(), tmp_file_name, err])
			saved_player_id.erase(player.id)
			continue
		file.store_string(player.level_data)
		file.close()
		var dir = DirAccess.open("user://")
		if dir:
			dir.rename(tmp_file_name, player.level_file_name)
		print("[%s] 玩家 " % Time.get_time_string_from_system(), player.name, " 的关卡 ", player.level_file_name, " 的数据大小：%d" % player.level_data.length())
		print("[%s] 玩家 " % Time.get_time_string_from_system(), player.name, " 的关卡数据已缓存到本地")
		#print("[%s] 关卡预览：" % Time.get_time_string_from_system(), player.level_data)

		if saved_player_id.size() >= multiplayer_manager.players.size():
			saved_player_id = []
