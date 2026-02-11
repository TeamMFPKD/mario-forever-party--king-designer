extends Node

var multiplayer_manager : MultiplayerManager

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager

func next_level_die():
	next_level()
	# TODO: 向host发送 关卡名 - 死亡 数据
	pass

func next_level_pass():
	next_level()
	# TODO: 向host发送 关卡名 - 通过 数据
	pass

func next_level():
	if MPManager.current_level_count < MPManager.total_levels - 1:
		MPManager.current_level_count += 1
		var fc = func():
			get_tree().reload_current_scene()
		print("player dead and should go to next level")
		fc.call_deferred()
	else:
		get_tree().change_scene_to_file("uid://c0civs02iqoki")
