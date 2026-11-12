extends Node

## 百人团游玩场景的推进器。
## 场景里的 GoalGate / PlayerDead 通过 play_next_level_manager 组找到它。


func next_level_pass() -> void:
	_close_pause_menu()
	Adventure.on_level_passed()
	var finished: bool = not Adventure.is_running()
	Adventure.play_transition(
		"finish" if finished else "pass",
		Adventure.RESULT_SCENE if finished else ""
	)


func next_level_die() -> void:
	_close_pause_menu()
	Adventure.on_player_died()
	# 死亡不需要专门的 (×) 动画，直接走全局淡出。
	if Adventure.is_running():
		GlobalTransition.reload_current_scene()
	else:
		GlobalTransition.change_scene_to_file(Adventure.RESULT_SCENE)


func _close_pause_menu() -> void:
	get_tree().paused = false
	var menu: Node = find_child("AdventurePauseMenu", true, false)
	if menu != null and menu.has_method("force_close"):
		menu.call("force_close")
