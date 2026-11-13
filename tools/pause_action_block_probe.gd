extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument", "unsafe_method_access", "unsafe_property_access")

## 无头探针：过关 / 转场期间允许暂停，但排除 / 跳过 / 中断三个动作置灰。
## 运行：Godot --headless --path . res://tools/pause_action_block_probe.tscn

const OUTPUT: String = "res://tools/pause_action_block_probe_result.txt"
const MENU: String = "res://object/ui/adventure_pause_menu.tscn"
const TRANSITION: String = "res://object/ui/adventure_clear_transition.tscn"
const BUTTONS: String = "Root/CardHolder/CardContainer/CardViewport/BackPanel/Content/VBox/Center/Buttons"

var _lines: Array[String] = []
var _menu: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	_write()
	_cleanup()
	get_tree().quit()


func _run() -> void:
	var packed: PackedScene = load(MENU) as PackedScene
	if packed == null:
		_lines.append("menu=missing")
		return
	_menu = packed.instantiate()
	_menu.set("usable_outside_adventure", true)
	add_child(_menu)
	await get_tree().process_frame

	var exclude: Button = _menu.get_node(BUTTONS + "/ExcludeButton") as Button
	var skip: Button = _menu.get_node(BUTTONS + "/SkipButton") as Button
	var abort: Button = _menu.get_node(BUTTONS + "/AbortButton") as Button
	var cont: Button = _menu.get_node(BUTTONS + "/ContinueButton") as Button
	if exclude == null or skip == null or abort == null or cont == null:
		_lines.append("buttons=missing")
		return

	_lines.append("blocked_initial=%s" % str(Adventure.is_pause_action_blocked()))
	_lines.append("idle_exclude=%s" % str(exclude.disabled))
	_lines.append("idle_skip=%s" % str(skip.disabled))
	_lines.append("idle_abort=%s" % str(abort.disabled))

	# 碰到终点：信号回调要立刻把三个动作置灰。
	Adventure.notify_level_passed()
	_lines.append("blocked_after_goal=%s" % str(Adventure.is_pause_action_blocked()))
	_lines.append("goal_exclude=%s" % str(exclude.disabled))
	_lines.append("goal_skip=%s" % str(skip.disabled))
	_lines.append("goal_abort=%s" % str(abort.disabled))
	_lines.append("goal_continue=%s" % str(cont.disabled))

	# 用 pause 动作走键盘链路：被置灰的窗口里也必须能打开菜单。
	var pause_event: InputEventAction = InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	_menu.call("_unhandled_input", pause_event)
	await get_tree().process_frame
	_lines.append("menu_open_while_blocked=%s" % str(bool(_menu.get("_is_open"))))
	_lines.append("paused_while_blocked=%s" % str(get_tree().paused))

	# 三个动作即使被外部强行 emit 也不能推进团 / 切场景 / 解冻。
	var run_before: bool = Adventure.is_running()
	exclude.pressed.emit()
	skip.pressed.emit()
	abort.pressed.emit()
	_lines.append("paused_after_actions=%s" % str(get_tree().paused))
	_lines.append("menu_open_after_actions=%s" % str(bool(_menu.get("_is_open"))))
	_lines.append("run_unchanged=%s" % str(Adventure.is_running() == run_before))

	# 推进换关前会等菜单关掉：0.35s 才关菜单，wait 若立刻返回下面的标记就是 false。
	var flags: Dictionary = {"early_open": false, "closed": false}
	var early_timer: SceneTreeTimer = get_tree().create_timer(0.15, true, false, true)
	early_timer.timeout.connect(
		func() -> void: flags["early_open"] = bool(_menu.get("_is_open")),
		CONNECT_ONE_SHOT
	)
	var close_timer: SceneTreeTimer = get_tree().create_timer(0.35, true, false, true)
	close_timer.timeout.connect(
		func() -> void:
			flags["closed"] = true
			_menu.call("force_close"),
		CONNECT_ONE_SHOT
	)
	await Adventure.wait_pause_menu_closed()
	_lines.append("menu_still_open_while_waiting=%s" % str(bool(flags.get("early_open", false))))
	_lines.append("wait_resumes_after_close=%s" % str(bool(flags.get("closed", false))))

	# 常规过关路径：菜单没开时等待必须立刻返回，不能把推进器卡住。
	var idle_flags: Dictionary = {"timed_out": false}
	var idle_timer: SceneTreeTimer = get_tree().create_timer(0.25, true, false, true)
	idle_timer.timeout.connect(func() -> void: idle_flags["timed_out"] = true, CONNECT_ONE_SHOT)
	await Adventure.wait_pause_menu_closed()
	_lines.append("wait_returns_when_closed=%s" % str(not bool(idle_flags.get("timed_out", true))))

	# 状态解除后三个动作恢复可用。
	Adventure.call("_set_level_passed_busy", false)
	_lines.append("blocked_after_reset=%s" % str(Adventure.is_pause_action_blocked()))
	_lines.append("reset_exclude=%s" % str(exclude.disabled))
	_lines.append("reset_skip=%s" % str(skip.disabled))
	_lines.append("reset_abort=%s" % str(abort.disabled))

	# 转场播放中同样走同一个信号。
	Adventure.set("_pass_transition_busy", true)
	Adventure.emit_signal("pause_actions_blocked_changed")
	_lines.append("blocked_by_transition=%s" % str(Adventure.is_pause_action_blocked()))
	_lines.append("transition_exclude=%s" % str(exclude.disabled))
	_lines.append("transition_skip=%s" % str(skip.disabled))
	_lines.append("transition_abort=%s" % str(abort.disabled))
	Adventure.set("_pass_transition_busy", false)
	Adventure.emit_signal("pause_actions_blocked_changed")
	_lines.append("transition_done_exclude=%s" % str(exclude.disabled))

	await _check_transition_pause()


## 过场动画中暂停：卡片背后露出场景自带的 psc.png 背景（不再有白色垫底），
## 解除暂停要有完整的翻回动画。
func _check_transition_pause() -> void:
	_lines.append("white_backdrop_removed=%s" % str(
		_menu.get_node_or_null("Root/CardHolder/Backdrop") == null
	))
	var transition: Node = null
	var packed: PackedScene = load(TRANSITION) as PackedScene
	if packed != null:
		transition = packed.instantiate()
		add_child(transition)
		Adventure.register_clear_transition(transition as CanvasLayer)

	Adventure.set("_pass_transition_busy", true)
	Adventure.emit_signal("pause_actions_blocked_changed")
	get_tree().paused = false
	_menu.call("toggle_pause")
	await _settle_menu()
	if transition != null:
		_lines.append("transition_frozen_on_open=%s" % str(bool(transition.get("_menu_paused"))))

	# 关菜单 0.15s 后翻转应仍在进行；wait 必须等动画播完才返回。
	var mid: Dictionary = {"animating": false}
	var mid_timer: SceneTreeTimer = get_tree().create_timer(0.15, true, false, true)
	mid_timer.timeout.connect(
		func() -> void: mid["animating"] = bool(_menu.get("_animating")),
		CONNECT_ONE_SHOT
	)
	_menu.call("toggle_pause")
	await Adventure.wait_pause_menu_closed()
	_lines.append("close_animation_played=%s" % str(bool(mid.get("animating", false))))
	_lines.append("close_animation_finished=%s" % str(not bool(_menu.get("_animating"))))
	_lines.append("still_paused_in_transition=%s" % str(get_tree().paused))
	if transition != null:
		_lines.append("transition_resumed=%s" % str(not bool(transition.get("_menu_paused"))))

	# 回归：非转场时关菜单仍要正常解冻。
	Adventure.set("_pass_transition_busy", false)
	Adventure.emit_signal("pause_actions_blocked_changed")
	_menu.call("toggle_pause")
	await _settle_menu()
	_menu.call("toggle_pause")
	await Adventure.wait_pause_menu_closed()
	_lines.append("normal_close_unpauses=%s" % str(not get_tree().paused))


func _settle_menu() -> void:
	var guard: int = 0
	while bool(_menu.get("_animating")) and guard < 240:
		await get_tree().process_frame
		guard += 1


func _write() -> void:
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
		file.close()


func _cleanup() -> void:
	get_tree().paused = false
	Adventure.set("_level_passed_busy", false)
	Adventure.set("_pass_transition_busy", false)
