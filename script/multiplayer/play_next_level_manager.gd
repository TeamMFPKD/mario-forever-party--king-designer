extends Node

var multiplayer_manager : MultiplayerManager

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager

func next_level_die():
	# 向host发送 关卡名 - 死亡 数据
	multiplayer_manager.level_add_pass_count.rpc_id(1, MPManager.random_levels[MPManager.current_level_count], false, MPManager.player.id)
	if LifeManager.lives > 1:
		LifeManager.lives -= 1
		get_tree().reload_current_scene()
		return
	next_level()

func next_level_pass():
	# 向host发送 关卡名 - 通过 数据
	multiplayer_manager.level_add_pass_count.rpc_id(1, MPManager.random_levels[MPManager.current_level_count], true, MPManager.player.id)
	next_level()

func next_level():
	LifeManager.is_lives_set_when_ready = false
	if MPManager.current_level_count < MPManager.total_levels - 1:
		MPManager.current_level_count += 1
		var fc = func():
			get_tree().reload_current_scene()
		print("[%s] [PlayNextLevelManager] player dead and should go to next level" % Time.get_time_string_from_system())
		fc.call_deferred()
	else:
		get_tree().change_scene_to_file("uid://c0civs02iqoki")