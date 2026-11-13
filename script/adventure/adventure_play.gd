extends Node2D

@warning_ignore_start("unsafe_call_argument", "unsafe_cast")

## 百人团游玩场景：清掉编辑/超时/截图等无关节点。
## 左侧关卡信息面板是场景自带的子节点 GameRoomSize/AdventureLevelInfo。
## 暂停菜单在子节点 AdventurePauseMenu（CanvasLayer，PROCESS_MODE_ALWAYS）。

const LEVEL_TIME_LIMIT: float = 30.0

var _game_timer: Timer
var _level_manager: Node
var _pause_button: Button


func _ready() -> void:
	# 防止上一场景在暂停状态下重载，导致新关卡启动即冻结。
	get_tree().paused = false
	_remove_node("TimeoutManager")
	_remove_node("GameRoomSize/MarginContainer")
	_remove_node("GameRoomSize/SubViewportContainer/SubViewport/RandomCapture")
	_remove_node("GameRoomSize/SubViewportContainer/SubViewport/Level/SaveLevel")
	Adventure.register_clear_transition(_find_clear_transition())
	_build_pause_button()
	# 过关中 / 转场播放中把暂停按钮置灰（信号回调不受暂停影响）。
	Adventure.pause_blocked_changed.connect(_refresh_pause_button)
	_setup_level_timer()
	# 从舞台进来时 BGM 已按所选难度在播；直接进游玩（探针 / 意外路径）时这里补上。
	Adventure.play_bgm(Adventure.current_tier())


func _setup_level_timer() -> void:
	var hud: Control = get_node_or_null("GameRoomSize/GameTimeHUD") as Control
	if hud == null:
		return
	hud.visible = true
	hud.z_index = 10
	# 和 history play 一致：倒计时放在右上角。
	hud.anchor_left = 1.0
	hud.anchor_right = 1.0
	hud.anchor_top = 0.0
	hud.anchor_bottom = 0.0
	hud.offset_left = -233.0
	hud.offset_right = 0.0
	hud.offset_top = 0.0
	hud.offset_bottom = 233.0

	_game_timer = hud.get_node_or_null("GameTimer") as Timer
	if _game_timer != null:
		_game_timer.stop()
		_game_timer.timeout.connect(_on_time_out)

	_level_manager = get_node_or_null(
		"GameRoomSize/SubViewportContainer/SubViewport/Level/LevelManager"
	)
	if _level_manager != null and _level_manager.has_signal("level_data_loaded"):
		_level_manager.connect("level_data_loaded", Callable(self, "_on_level_data_loaded"))


func _on_level_data_loaded() -> void:
	if _game_timer == null:
		return
	# 百人团固定 30 秒，不读关卡自己的 time_used。
	_game_timer.wait_time = LEVEL_TIME_LIMIT
	_game_timer.start()


func _on_time_out() -> void:
	if not Adventure.is_running():
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or player.has_meta("level_passed"):
		return
	var hurt_and_die: Node = player.get_meta("player_hurt_and_die", null) as Node
	if hurt_and_die != null and hurt_and_die.has_method("kill"):
		hurt_and_die.call("kill")


func _build_pause_button() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MobilePauseLayer"
	layer.layer = 20
	add_child(layer)

	var button: Button = Button.new()
	button.name = "MobilePauseButton"
	button.text = "II"
	button.tooltip_text = "暂停"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(72, 72)
	button.add_theme_font_size_override("font_size", 30)
	# 倒计时占了右上角，暂停键放左上角，避开左侧信息面板顶部。
	# 桌面端也显示：鼠标可直接点，键盘仍可用 P / Esc。
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	button.offset_left = 24
	button.offset_top = 24
	button.offset_right = 96
	button.offset_bottom = 96
	button.pressed.connect(_on_pause_pressed)
	layer.add_child(button)
	_pause_button = button
	_refresh_pause_button()


## 过关中 / 过关转场播放中：暂停按钮置灰，点不动。
func _refresh_pause_button() -> void:
	if _pause_button == null:
		return
	_pause_button.disabled = Adventure.is_pause_blocked()


func _on_pause_pressed() -> void:
	if Adventure.is_pause_blocked():
		return
	var menu: Node = find_child("AdventurePauseMenu", true, false)
	if is_instance_valid(menu) and menu.has_method("toggle_pause"):
		menu.call("toggle_pause")


## 过关转场挂在关卡 SubViewport 里，按 640×480 的关卡坐标系播放。
func _find_clear_transition() -> CanvasLayer:
	return get_node_or_null("GameRoomSize/SubViewportContainer/SubViewport/AdventureClearTransition") as CanvasLayer


func _remove_node(path: String) -> void:
	var node: Node = get_node_or_null(path)
	if node != null:
		# 先停掉处理（含 Timer），避免 queue_free 到真正释放之间还触发 capture/save。
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.queue_free()
