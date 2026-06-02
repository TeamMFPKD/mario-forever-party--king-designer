extends CharacterBody2D

signal player_dead
signal next_level

var play_next_level_node : Node

func _ready() -> void:
	play_next_level_node = get_tree().get_first_node_in_group("play_next_level_manager")
	if play_next_level_node:
		next_level.connect(play_next_level_node.next_level_die)
	else:
		push_warning("play_next_level_manager is not assigned in PlayerDead")
	if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.TEST:
		player_dead.connect(GameModeSingleton.go_to_edit)
		print("[player_dead.gd] player dead and should go to edit")
	elif GameModeSingleton.game_mode == GameModeSingleton.GameModeType.PLAY:
		await get_tree().create_timer(1.2).timeout
		emit_signal("next_level")
	elif GameModeSingleton.game_mode == GameModeSingleton.GameModeType.HISTORY_PLAY:
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(self) and is_inside_tree():
			get_tree().reload_current_scene()
	emit_signal("player_dead")
