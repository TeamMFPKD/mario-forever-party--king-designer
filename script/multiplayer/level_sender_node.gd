extends Node

signal lets_play_together

var multiplayer_manager : MultiplayerManager

var local_players_level_data_ready : bool = false
var all_players_data_ready : bool = false
var wait_time_initial = 1.0
var wait_time_local = 1.0
var wait_time_sever = 1.0

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	
	# 检查原始 JSON 是否有效
	var raw_json = multiplayer_manager.player.level_data
	if raw_json.is_empty() or raw_json == "invalid":
		push_error("[%s] player.level_data 无效，无法发送" % Time.get_time_string_from_system())
		return
	
	var level_data_bytes = raw_json.to_utf8_buffer()
	var level_data_bytes_compressed = level_data_bytes.compress(FileAccess.CompressionMode.COMPRESSION_DEFLATE)
	
	print("[%s] [LevelSender] 原始 JSON 大小：%.2f KB，压缩后：%.2f KB" % [Time.get_time_string_from_system(), level_data_bytes.size() / 1024.0, level_data_bytes_compressed.size() / 1024.0])
	
	multiplayer_manager.transfer_level_data.rpc(
		multiplayer_manager.player.id,
		multiplayer_manager.player.level_file_name,
		level_data_bytes_compressed
	)

	# 先等 wait_time_initial 秒
	await get_tree().create_timer(wait_time_initial).timeout
	
	#multiplayer_manager.emit_signal("players_updated")
	print("[%s] [LevelSender] Level data sent." % Time.get_time_string_from_system())

	while not local_players_level_data_ready:
		local_players_level_data_ready = true
		print("[%s] [LevelSender] 确认玩家关卡数据" % Time.get_time_string_from_system())
		for p in multiplayer_manager.players:
			if p.level_data != "invalid":
				print("[%s] [LevelSender] 已接收玩家 %s 的关卡数据" % [Time.get_time_string_from_system(), MPManager.format_player(p.name, p.id)])
			else:
				print("[%s] [LevelSender] 确认玩家 %s 的关卡数据无效。" % [Time.get_time_string_from_system(), MPManager.format_player(p.name, p.id)])
				local_players_level_data_ready = false
		if not local_players_level_data_ready:
			# 失败了！再等 wait_time_local 秒
			print("[%s] [LevelSender] 等待 " % Time.get_time_string_from_system(), wait_time_local, " 秒")
			await get_tree().create_timer(wait_time_local).timeout

	multiplayer_manager.my_players_data_are_ready.rpc_id(1, multiplayer_manager.player.id)

	if not multiplayer_manager.multiplayer.is_server():
		return

	while not all_players_data_ready:
		all_players_data_ready = true
		print("[%s] [LevelSender] 确认所有玩家就绪" % Time.get_time_string_from_system())
		for p in multiplayer_manager.players:
			if not p.ready:
				print("[%s] [LevelSender] 玩家 %s 未就绪。" % [Time.get_time_string_from_system(), MPManager.format_player(p.name, p.id)])
				all_players_data_ready = false
			else:
				print("[%s] [LevelSender] 玩家 %s 已就绪。" % [Time.get_time_string_from_system(), MPManager.format_player(p.name, p.id)])
		print("[%s] [LevelSender] 等待 " % Time.get_time_string_from_system(), wait_time_sever, " 秒")
		await get_tree().create_timer(wait_time_sever).timeout

	# Geimu Sutato!
	print("[%s] [LevelSender] 所有玩家准备就绪，开始游戏！" % Time.get_time_string_from_system())
	emit_signal("lets_play_together")