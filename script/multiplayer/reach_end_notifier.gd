extends Node

var multiplayer_manager : MultiplayerManager

var all_players_reach_end : bool = false
var wait_time : float = 1.5

@export_category("Final Score Calculation")
@export var a : float = 0.7
@export var k : float = 5.0

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.reach_end.rpc_id(1, multiplayer_manager.player.id)

	if not multiplayer_manager.multiplayer.is_server():
		return
	
	while not all_players_reach_end:
		all_players_reach_end = true
		for player in multiplayer_manager.players:
			if not player["reach_end"]:
				print("[%s] 玩家 %s 未到达终点" % [Time.get_time_string_from_system(), MPManager.format_player(player["name"], player["id"])])
				all_players_reach_end = false
		print("[%s] 等待 " % Time.get_time_string_from_system(), wait_time, " 秒")
		await get_tree().create_timer(wait_time).timeout

	print("[%s] 所有玩家已到达终点。" % Time.get_time_string_from_system())
	print("[%s] 计算结果中……" % Time.get_time_string_from_system())
	for player in multiplayer_manager.players:
		var level_pass_count = player["level_pass_count"]
		var level_cause_pass = player["level_cause_pass"]
		var level_cause_death = player["level_cause_death"]
		var clear_rate = (float)(level_cause_pass) / (float)(level_cause_pass + level_cause_death)
		var score_clear_rate = 100.0 * ( (clear_rate/a)**(k*a) ) * ( ((1-clear_rate)/(1-a))**(k*(1-a)) )
		var score_level_pass = 100.0 * (float(level_pass_count) / float(multiplayer_manager.players.size()))
		var score = round(score_clear_rate * 0.6 + score_level_pass * 0.4)
		player["clear_rate"] = clear_rate
		player["score"] = score

		# 清空所有玩家的关卡数据内容，减少数据传输量
		player["level_data"] = "invalid"
	multiplayer_manager.store_level_results.rpc(multiplayer_manager.players)
	print("[%s] 关卡游玩数据已广播" % Time.get_time_string_from_system())