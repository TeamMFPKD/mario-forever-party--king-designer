extends Node

## 无头探针：回放页暂停时按「返回」，树要解冻、场景要真的切回去。
##
## 与 tools/history_pause_click_probe 的区别：那个只验证点击链路（并故意断开跳转），
## 这个跑完整链路 —— 暂停中合成一次点击 → AdventurePauseMenu._on_underlying_pressed()
## 调 force_close() 解冻 → JumpToSceneHistory.jump_to_scene() 切回 history 房间。
##
## 运行：
##   Godot --headless --path . res://tools/history_pause_exit_probe.tscn
##
## 判据（关键行）：
##   back_mode=3            修复后按钮在暂停中仍参与处理
##   paused_before_click=true
##   paused_after_click=false   ← 卡片收起时同步解冻
##   scene_changed=true        ← 真的离开了回放页

const OUTPUT: String = "res://tools/history_pause_exit_probe_result.txt"
const HISTORY_PLAY_SCENE: String = "res://room/history_play.tscn"
const BACK_BUTTON_PATH: String = "GameRoomSize/BackToHistory/BackToHistoryButton"

var _watch_mode: bool = false
var _log: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _watch_mode:
		set_process(false)
		_wait_and_click()
		return
	# 引导器：回放页必须是 current_scene，而监听节点要活过那次切换
	GameModeSingleton.game_mode = GameModeSingleton.GameModeType.HISTORY_PLAY
	var watcher: Node = Node.new()
	watcher.name = "HistoryPauseExitWatcher"
	watcher.set_script(get_script())
	watcher.set("_watch_mode", true)
	get_tree().root.add_child.call_deferred(watcher)
	await get_tree().process_frame
	var err: int = get_tree().change_scene_to_file(HISTORY_PLAY_SCENE)
	if err != OK:
		_finish("bootstrap_error=change scene failed: %d" % err)


func _wait_and_click() -> void:
	await get_tree().create_timer(3.0, true).timeout
	var scene: Node = get_tree().current_scene
	_log.append("scene_before=%s" % (str(scene.name) if scene != null else "<null>"))
	if scene == null:
		_finish("")
		return
	var back: Button = scene.get_node_or_null(BACK_BUTTON_PATH) as Button
	if back == null:
		_finish("back_found=false")
		return
	_log.append("back_found=true")
	_log.append("back_mode=%d" % int(back.process_mode))
	var point: Vector2 = back.get_global_transform_with_canvas() * (back.size * 0.5)
	get_tree().paused = true
	await get_tree().process_frame
	_log.append("paused_before_click=%s" % str(get_tree().paused))

	# 与 UiNavigator 同一条合成点击路径
	_send(point, true)
	for i: int in range(3):
		await get_tree().process_frame
	_send(point, false)
	for i: int in range(30):
		await get_tree().process_frame

	_log.append("paused_after_click=%s" % str(get_tree().paused))
	var now: Node = get_tree().current_scene
	_log.append("scene_after=%s" % (str(now.name) if now != null else "<null>"))
	_log.append("scene_changed=%s" % str(now != null and str(now.name) != "Play"))
	_log.append("exit_ok=%s" % str(not get_tree().paused and now != null and str(now.name) != "Play"))
	_finish("")


func _send(point: Vector2, pressed: bool) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	# 与 UiNavigator 一致：坐标已是视口局部坐标
	viewport.push_input(event, true)


func _finish(extra: String) -> void:
	if not extra.is_empty():
		_log.append(extra)
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log))
		file.close()
	get_tree().quit()
