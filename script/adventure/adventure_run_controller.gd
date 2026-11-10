extends Node

## 百人团游玩场景的推进器。
## 场景里的 GoalGate / PlayerDead 通过 play_next_level_manager 组找到它。


func next_level_pass() -> void:
	Adventure.on_level_passed()
	var finished: bool = not Adventure.is_running()
	Adventure.play_transition(
		"finish" if finished else "pass",
		Adventure.RESULT_SCENE if finished else ""
	)


func next_level_die() -> void:
	Adventure.on_player_died()
	var finished: bool = not Adventure.is_running()
	Adventure.play_transition(
		"death",
		Adventure.RESULT_SCENE if finished else ""
	)
