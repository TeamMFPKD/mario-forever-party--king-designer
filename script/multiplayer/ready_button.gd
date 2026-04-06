extends Button

var multiplayer_manager : MultiplayerManager
var is_ready : bool = false
var last_input_time : float = 0.0
var total_time : float = 0.0
var window_focused : bool = true
var unfocused_time : float = 0.0  # 失焦持续时间
var player

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager")
	pressed.connect(_on_button_pressed)
	last_input_time = Time.get_unix_time_from_system()
	get_window().focus_entered.connect(_on_window_focus_entered)
	get_window().focus_exited.connect(_on_window_focus_exited)

func _process(_delta: float) -> void:
	if not multiplayer_manager:
		return
	for p in multiplayer_manager.players:
		if p.id == multiplayer_manager.player.id:
			player = p
	if not player:
		return
	is_ready = player.is_ready_to_start
	if is_ready:
		set_disabled(true)
		
		# 检查超时条件
		_check_timeout_conditions()
	else:
		set_disabled(false)

func _on_button_pressed() -> void:
	multiplayer_manager.get_ready.rpc(multiplayer_manager.player.id, true)

func off_ready() -> void:
	multiplayer_manager.get_ready.rpc(multiplayer_manager.player.id, false)

func _input(event: InputEvent) -> void:
	# 检测任何输入事件
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		last_input_time = Time.get_unix_time_from_system()

func _on_window_focus_entered() -> void:
	window_focused = true
	unfocused_time = 0.0  # 重置失焦时间

func _on_window_focus_exited() -> void:
	window_focused = false
	unfocused_time = 0.0  # 开始计时失焦时间

func _check_timeout_conditions() -> void:
	var current_time = Time.get_unix_time_from_system()
	
	# 检查输入超时
	if current_time - last_input_time > 20.0:
		off_ready()
		return
	
	# 检查窗口失焦 - 失焦状态下保持一段时间后才调用off_ready()
	if not window_focused:
		unfocused_time += get_process_delta_time()
		if unfocused_time > 10.0:
			off_ready()
			return
	else:
		unfocused_time = 0.0  # 重置失焦时间
	
	# 检查总超时
	total_time += get_process_delta_time()
	if total_time > 120.0:
		off_ready()
		return
