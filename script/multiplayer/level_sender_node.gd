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
	multiplayer_manager.transfer_level_data.rpc(
		multiplayer_manager.player.id,
		multiplayer_manager.player.level_file_name,
		multiplayer_manager.player.level_data
	)
	print("Level data sent.")

	# 先等 wait_time_initial 秒
	await get_tree().create_timer(wait_time_initial).timeout

	while not local_players_level_data_ready:
		local_players_level_data_ready = true
		print("[确认玩家关卡数据]")
		for p in multiplayer_manager.players:
			if p.level_data != "invalid":
				print("已接收玩家 ", p.name, " 的关卡数据")
			else:
				print("玩家 ", p.name, " 的关卡数据无效。")
				local_players_level_data_ready = false
		if not local_players_level_data_ready:
			# 失败了！再等 wait_time_local 秒
			print("等待 ", wait_time_local, " 秒")
			await get_tree().create_timer(wait_time_local).timeout

	multiplayer_manager.my_players_data_are_ready.rpc_id(1, multiplayer_manager.player.id)

	if not multiplayer_manager.multiplayer.is_server():
		return

	while not all_players_data_ready:
		all_players_data_ready = true
		print("[确认所有玩家就绪]")
		for p in multiplayer_manager.players:
			if not p.ready:
				print("玩家 ", p.name, " 未就绪。")
				all_players_data_ready = false
			else:
				print("玩家 ", p.name, " 已就绪。")
		print("等待 ", wait_time_sever, " 秒")
		await get_tree().create_timer(wait_time_sever).timeout

	# Geimu Sutato!
	print("所有玩家准备就绪，开始游戏！")
	emit_signal("lets_play_together")
