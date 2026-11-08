extends Node

## 各客户端的关卡推进保持“各玩各的”：本地索引独立递增，
## 只把单关结果上报主机用于结算聚合。


func next_level_die() -> void:
	_report_current_level(false)
	if LifeManager.lives > 1:
		LifeManager.lives -= 1
		GlobalTransition.reload_current_scene()
		return
	next_level()


func next_level_pass() -> void:
	_report_current_level(true)
	next_level()


func next_level() -> void:
	LifeManager.is_lives_set_when_ready = false
	if MPManager.current_level_count < MPManager.total_levels - 1:
		MPManager.current_level_count += 1
		Log.i("PlayNextLevelManager", "player dead and should go to next level")
		GlobalTransition.reload_current_scene()
	else:
		GlobalTransition.change_scene_to_file("uid://c0civs02iqoki")


func _report_current_level(passed: bool) -> void:
	var levels: Array[String] = MPManager.random_levels
	var index: int = MPManager.current_level_count
	if index < 0 or index >= levels.size():
		return
	MPManager.flow.report_level_result(levels[index], passed)
