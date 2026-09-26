extends Node

var multiplayer_manager: MultiplayerManager
var saved_player_id: Array = []

func _ready() -> void:
	multiplayer_manager = MPManager
	multiplayer_manager.players_updated.connect(self._players_updated)

# 将非空关卡数据缓存到本地
func _players_updated() -> void:
	if not multiplayer_manager.is_in_game:
		return
	for player: Variant in multiplayer_manager.players:
		var level_data: String = player.level_data
		var level_file_name: String = player.level_file_name
		if saved_player_id.has(player.id) or level_data == "invalid" or level_data.is_empty() or level_file_name == "invalid":
			continue
		saved_player_id.append(player.id)
		# 缓存非空关卡数据，使用原子写入保护
		var tmp_file_name: String = level_file_name + ".tmp"
		var file: FileAccess = FileAccess.open(tmp_file_name, FileAccess.WRITE)
		if not file:
			var err: int = FileAccess.get_open_error()
			push_error("[%s] 无法打开文件写入：%s, error: %d" % [Time.get_time_string_from_system(), tmp_file_name, err])
			saved_player_id.erase(player.id)
			continue
		file.store_string(level_data)
		file.close()
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			dir.rename(tmp_file_name, level_file_name)
		print("[%s] [LevelReceiver] 玩家 %s 的关卡 %s 的数据大小：%d" % [Time.get_time_string_from_system(), multiplayer_manager.format_player(player.name, player.id), level_file_name, level_data.length()])
		print("[%s] [LevelReceiver] 玩家 %s 的关卡数据已缓存到本地" % [Time.get_time_string_from_system(), multiplayer_manager.format_player(player.name, player.id)])
		#print("[%s] [LevelReceiver] 关卡预览：" % Time.get_time_string_from_system(), player.level_data)

		if saved_player_id.size() >= multiplayer_manager.players.size():
			saved_player_id = []
