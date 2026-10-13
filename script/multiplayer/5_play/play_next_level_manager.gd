extends Node

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = MPManager

func next_level_die() -> void:
	# 向host发送 关卡名 - 死亡 数据
	multiplayer_manager.level_add_pass_count.rpc_id(1, multiplayer_manager.random_levels[multiplayer_manager.current_level_count], false, multiplayer_manager.player.id)
	if LifeManager.lives > 1:
		LifeManager.lives -= 1
		get_tree().reload_current_scene()
		return
	next_level()

func next_level_pass() -> void:
	# 向host发送 关卡名 - 通过 数据
	multiplayer_manager.level_add_pass_count.rpc_id(1, multiplayer_manager.random_levels[multiplayer_manager.current_level_count], true, multiplayer_manager.player.id)
	next_level()

func next_level() -> void:
	LifeManager.is_lives_set_when_ready = false
	if multiplayer_manager.current_level_count < multiplayer_manager.total_levels - 1:
		multiplayer_manager.current_level_count += 1
		var fc: Callable = func() -> void:
			get_tree().reload_current_scene()
		print("[%s] [PlayNextLevelManager] player dead and should go to next level" % Time.get_time_string_from_system())
		fc.call_deferred()
	else:
		get_tree().change_scene_to_file("uid://c0civs02iqoki")