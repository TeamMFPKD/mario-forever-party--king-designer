extends UiSoundButton

var is_ready: bool = false
var last_input_time: float = 0.0
var total_time: float = 0.0
var window_focused: bool = true
var unfocused_time: float = 0.0
# 本机多开测试时跳过“失焦/无输入/总时长自动取消准备”，
# 否则同一时间只有一个窗口在前台，其余窗口 10 秒后会被自动取消准备。
var skip_auto_unready: bool = false


func _ready() -> void:
	super()
	skip_auto_unready = MpTest.has("--mp-no-ready-timeout")
	pressed.connect(_on_button_pressed)
	last_input_time = Time.get_unix_time_from_system()
	get_window().focus_entered.connect(_on_window_focus_entered)
	get_window().focus_exited.connect(_on_window_focus_exited)


func _process(_delta: float) -> void:
	var local: PlayerProfile = MPManager.get_local_player()
	if local.is_spectator:
		visible = false
		return
	visible = true
	is_ready = local.lobby_ready
	if is_ready:
		set_disabled(true)
		if not skip_auto_unready:
			_check_timeout_conditions()
	else:
		set_disabled(false)


func _on_button_pressed() -> void:
	MPManager.lobby.set_lobby_ready(true)


func off_ready() -> void:
	MPManager.lobby.set_lobby_ready(false)


func _input(event: InputEvent) -> void:
	# 检测任何输入事件
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		last_input_time = Time.get_unix_time_from_system()


func _on_window_focus_entered() -> void:
	window_focused = true
	unfocused_time = 0.0


func _on_window_focus_exited() -> void:
	window_focused = false
	unfocused_time = 0.0


func _check_timeout_conditions() -> void:
	var current_time: float = Time.get_unix_time_from_system()

	# 检查输入超时
	if current_time - last_input_time > 20.0:
		off_ready()
		return

	# 检查窗口失焦 - 失焦状态下保持一段时间后才调用 off_ready()
	if not window_focused:
		unfocused_time += get_process_delta_time()
		if unfocused_time > 10.0:
			off_ready()
			return
	else:
		unfocused_time = 0.0

	# 检查总超时
	total_time += get_process_delta_time()
	if total_time > 120.0:
		off_ready()
