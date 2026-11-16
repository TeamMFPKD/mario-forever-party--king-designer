extends Node

## 无头探针：验证回放页暂停时「查看 / 返回」能被 UiNavigator 的合成点击命中。
##
## 运行：
##   Godot --headless --path . res://tools/history_pause_click_probe.tscn
##
## 现象（修复前）：暂停菜单打开后，方向键能把四角红框移到「查看 / 返回」上，
## 按下确认键红框还会变黄，但按钮毫无反应，纯键盘 / 手柄退不出回放页。
##
## 原因：卡片上的按钮能吃下点击，是因为 AdventurePauseMenu 这个 CanvasLayer 是
## PROCESS_MODE_ALWAYS；「查看 / 返回」挂在关卡场景树上，默认随树暂停。
## Godot 派发鼠标事件前会查目标 can_process()（Viewport::_gui_input_event），
## 可暂停的控件被静默丢弃 —— 红框变黄只是 UiNavigator 自己画的表现，
## 连 AdventurePauseMenu 里 "按下就解冻" 的兜底也进不去。
## 修复：HistoryPauseMenu 在回放页把这两个按钮提到 PROCESS_MODE_ALWAYS。
##
## 判据（关键行）：
##   pause_menu_found=true
##   view_is_always_from_menu=true / back_is_always_from_menu=true
##   pausable_blocked=true      ← 复现：同样一次点击，随树暂停时收不到
##   always_click_ok=true       ← 修复后：暂停中仍能收到 pressed
##   unpaused_can_process=true
##
## 本文件同时充当"引导器"和"监听节点"：回放页必须是 current_scene，
## 而 current_scene 会在切场景时被释放，所以监听节点由引导器建好挂到 root 上。

const OUTPUT: String = "res://tools/history_pause_click_probe_result.txt"
const HISTORY_PLAY_SCENE: String = "res://room/history_play.tscn"
const BACK_BUTTON_PATH: String = "GameRoomSize/BackToHistory/BackToHistoryButton"
const VIEW_BUTTON_PATH: String = "GameRoomSize/MarginContainer/Button"
const JUMPER_PATH: String = "JumpToSceneHistory"

## 等回放页把关卡、暂停菜单、_connect_underlying_buttons 的 call_deferred 全部跑完
const WAIT_SECONDS: float = 3.0

## true = 监听节点（挂在 root 上，切场景不释放）；false = 引导器
var _watch_mode: bool = false

var _press: int = 0
var _release: int = 0
var _pressed: int = 0
var _log: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _watch_mode:
		set_process(false)
		_begin_watch()
		return
	_boot()


# ---------------------------------------------------------------------------
# 引导器
# ---------------------------------------------------------------------------

func _boot() -> void:
	GameModeSingleton.game_mode = GameModeSingleton.GameModeType.HISTORY_PLAY
	var watcher: Node = Node.new()
	watcher.name = "HistoryPauseClickWatcher"
	watcher.set_script(get_script())
	watcher.set("_watch_mode", true)
	# 挂到 root：切场景只会释放旧的 current_scene，监听节点要活过这一次切换
	get_tree().root.add_child.call_deferred(watcher)
	await get_tree().process_frame
	var err: int = get_tree().change_scene_to_file(HISTORY_PLAY_SCENE)
	if err != OK:
		_write("bootstrap_error=change scene failed: %d" % err)
		get_tree().quit()


# ---------------------------------------------------------------------------
# 监听节点
# ---------------------------------------------------------------------------

func _begin_watch() -> void:
	await get_tree().create_timer(WAIT_SECONDS, true).timeout
	await _run()


func _run() -> void:
	var scene: Node = get_tree().current_scene
	_log.append("scene_name=%s" % (str(scene.name) if scene != null else "<null>"))
	if scene == null:
		_finish()
		return
	var back: Button = scene.get_node_or_null(BACK_BUTTON_PATH) as Button
	var view: Button = scene.get_node_or_null(VIEW_BUTTON_PATH) as Button
	var menu: Node = scene.get_node_or_null("HistoryPauseMenu")
	_log.append("back_found=%s" % str(back != null))
	_log.append("view_found=%s" % str(view != null))
	_log.append("pause_menu_found=%s" % str(menu != null))
	if back == null or view == null or menu == null:
		_finish()
		return

	# 回放页变体的两条约定：模态不独占焦点、Root 让点击穿透
	var root_control: Control = menu.get_node_or_null("Root") as Control
	_log.append("modal_inclusive=%s"
		% str(root_control != null and root_control.has_meta(&"ui_focus_modal_inclusive")))
	_log.append("root_mouse_filter_ignore=%s"
		% str(root_control != null and root_control.mouse_filter == Control.MOUSE_FILTER_IGNORE))

	# 修复由暂停菜单落实：两个按钮都该被提到 ALWAYS
	_log.append("view_is_always_from_menu=%s" % str(view.process_mode == Node.PROCESS_MODE_ALWAYS))
	_log.append("back_is_always_from_menu=%s" % str(back.process_mode == Node.PROCESS_MODE_ALWAYS))

	# 断开真实跳转：这里只验证点击链路，不能让一次点击把场景换掉
	var jumper: Node = scene.get_node_or_null(JUMPER_PATH)
	if jumper != null:
		for info: Dictionary in back.pressed.get_connections():
			var target: Variant = info.get("callable")
			if target is Callable:
				var callable: Callable = target
				if callable.get_object() == jumper:
					back.pressed.disconnect(callable)
					_log.append("jump_disconnected=true")

	back.gui_input.connect(_on_gui_input)
	back.pressed.connect(_count_pressed)
	var point: Vector2 = back.get_global_transform_with_canvas() * (back.size * 0.5)
	_log.append("click_point=%s" % str(point))

	get_tree().paused = true
	await get_tree().process_frame
	_log.append("paused=%s" % str(get_tree().paused))

	# 1. 复现修复前的状态：手动退回随树暂停
	back.process_mode = Node.PROCESS_MODE_PAUSABLE
	await get_tree().process_frame
	_log.append("pausable_can_process=%s" % str(back.can_process()))
	await _click(point)
	_log.append("pausable_press=%d release=%d pressed=%d" % [_press, _release, _pressed])
	_log.append("pausable_blocked=%s" % str(_press == 0 and _pressed == 0))
	_reset()

	# 2. 修复后的状态：暂停期间仍参与处理
	back.process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log.append("always_can_process=%s" % str(back.can_process()))
	await _click(point)
	_log.append("always_press=%d release=%d pressed=%d" % [_press, _release, _pressed])
	_log.append("always_click_ok=%s" % str(_pressed == 1))

	get_tree().paused = false
	_log.append("unpaused_can_process=%s" % str(back.can_process()))
	_finish()


func _count_pressed() -> void:
	_pressed += 1


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			_press += 1
		else:
			_release += 1


func _reset() -> void:
	_press = 0
	_release = 0
	_pressed = 0


## 在控件中心合成一次左键按下 + 抬起，与 UiNavigator._send_mouse_button 同一条路径。
func _click(point: Vector2) -> void:
	_send(point, true)
	for i: int in range(3):
		await get_tree().process_frame
	_send(point, false)
	for i: int in range(5):
		await get_tree().process_frame


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


func _finish() -> void:
	_write("\n".join(_log))
	get_tree().quit()


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
