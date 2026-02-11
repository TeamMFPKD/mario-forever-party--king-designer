extends Node

var multiplayer_manager : MultiplayerManager

var all_players_reach_end : bool = false
var wait_time : float = 3.0

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.reach_end.rpc_id(1, multiplayer_manager.player.id)

	if not multiplayer_manager.multiplayer.is_server():
		return
	
	while not all_players_reach_end:
		all_players_reach_end = true
		for player in multiplayer_manager.players:
			if not player["reach_end"]:
				print("玩家", player["id"], "未到达终点")
				all_players_reach_end = false
		print("等待 ", wait_time, "秒")
		await get_tree().create_timer(wait_time).timeout

	print("所有玩家已到达终点")
	print("结果是：")
	for player in multiplayer_manager.players:
		print("玩家 ", player["name"], " ：关卡通过率：", \
		(float)(player["level_cause_pass"]) / (float)(player["level_cause_pass"] + player["level_cause_death"]) * 100.0, "%"
		)
