extends Node

## 百人团游玩场景的推进器。
## 场景里的 GoalGate / PlayerDead 通过 play_next_level_manager 组找到它。


func next_level_pass() -> void:
	# 加载下一关期间场景已经暂停；万一还有残留的终点信号，别再推进一次进度。
	if Adventure.is_pass_transition_running():
		Log.w("AdventureRunController", "过关转场进行中，忽略重复的过关")
		return
	# 终点后 1 秒冻结期间玩家可以暂停：菜单留着，等「继续」后再推进，
	# 否则推进器会 force_close 掉刚打开的暂停菜单。
	await Adventure.wait_pause_menu_closed()
	_close_pause_menu(true)
	# 过场动画要显示「刚通过的是第几关」，必须在推进进度前取快照：
	# 跳过关卡会让通过数和实际关号错位，结算时 current_run 还会被清空。
	var level_number: int = Adventure.current_level_number()
	var total_levels: int = Adventure.current_total_levels()
	var passed_count: int = Adventure.cleared_count() + 1
	Adventure.on_level_passed()
	var finished: bool = not Adventure.is_running()
	# 固定按「团内第几关」显示；无尽显示「已通过 N 关」，用通过数。
	var display_number: int = level_number if total_levels > 0 else passed_count
	Adventure.play_transition(
		"finish" if finished else "pass",
		Adventure.result_scene() if finished else "",
		display_number,
		total_levels
	)


func next_level_die() -> void:
	_close_pause_menu()
	Adventure.on_player_died()
	# 死亡不需要专门的 (×) 动画，直接走全局淡出。
	if Adventure.is_running():
		GlobalTransition.reload_current_scene()
	else:
		GlobalTransition.change_scene_to_file(Adventure.result_scene())


## keep_paused：过关转场期间保持冻结，由 Adventure 在转场结束时统一解冻。
func _close_pause_menu(keep_paused: bool = false) -> void:
	var menu: Node = find_child("AdventurePauseMenu", true, false)
	if is_instance_valid(menu) and menu.has_method("force_close"):
		menu.call("force_close", keep_paused)
	elif not keep_paused:
		get_tree().paused = false
