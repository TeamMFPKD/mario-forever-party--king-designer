extends ControlVisibieSet

var mobile_control: MobileControl
var game_config: ConfigFile
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_target: Node2D = null  # Node2D 容器（D-pad）或 TouchScreenButton（右侧单按钮）

# 用于 _make_buttons_layout_default，在加载存档前记录场景初始值
var _default_dpad_pos: Vector2 = Vector2.ZERO
var _default_button_positions: Dictionary = {}  # action -> Vector2
var _original_dpad_pos: Vector2 = Vector2.ZERO
var _original_button_positions: Dictionary = {}  # action -> Vector2

func _ready() -> void:
	super._ready()
	mobile_control = get_tree().get_first_node_in_group("mobile_control")
	game_config = GameConfig.config
	_capture_original_positions()  # 记录真正的原始位置
	_check_and_save_default_layout()  # 检查并保存默认布局到config
	_load_positions()
	if control:
		control.gui_input.connect(_on_canvas_gui_input)

# ──────────────────────────────────────────────
# 检查并保存默认布局到config（如果没有配置文件）
# ──────────────────────────────────────────────
func _check_and_save_default_layout() -> void:
	# 如果没有移动布局配置，保存当前布局作为默认布局
	if not game_config.has_section("mobile_layout"):
		_save_default_layout_to_config()
	
	# 记录当前默认位置
	_capture_defaults()

# 记录真正的原始位置（在加载任何配置之前）
# ──────────────────────────────────────────────
func _capture_original_positions() -> void:
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var dpad: Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		_original_dpad_pos = dpad.position

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child: Node in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton:
				var btn: TouchScreenButton = child
				if not btn.action.is_empty():
					_original_button_positions[btn.action] = btn.position

# 记录场景当前默认位置（用于重置）
# ──────────────────────────────────────────────
func _capture_defaults() -> void:
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var dpad: Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		_default_dpad_pos = dpad.position

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child: Node in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton:
				var btn: TouchScreenButton = child
				if not btn.action.is_empty():
					_default_button_positions[btn.action] = btn.position

# ──────────────────────────────────────────────
# 显示 / 隐藏
# ──────────────────────────────────────────────
func _set_visible() -> void:
	super._set_visible()
	mobile_control.show_mode = MobileControl.ShowModeType.SHOW

func _set_invisible() -> void:
	super._set_invisible()
	mobile_control.show_mode = MobileControl.ShowModeType.HIDE

# ──────────────────────────────────────────────
# 输入处理
# ──────────────────────────────────────────────
func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pointer_position: Vector2 = Vector2.ZERO
		var pointer_pressed: bool = false
		if event is InputEventMouseButton:
			var mouse_button: InputEventMouseButton = event
			pointer_position = mouse_button.position
			pointer_pressed = mouse_button.pressed
		elif event is InputEventScreenTouch:
			var screen_touch: InputEventScreenTouch = event
			pointer_position = screen_touch.position
			pointer_pressed = screen_touch.pressed
		if pointer_pressed:
			drag_target = _get_target_from_position(pointer_position)
			if drag_target:
				is_dragging    = true
				drag_start_pos = pointer_position - drag_target.position
		else:
			if is_dragging:
				is_dragging = false
				drag_target = null
				_save_positions()

	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if is_dragging and drag_target:
			var pointer_position: Vector2 = Vector2.ZERO
			if event is InputEventMouseMotion:
				var mouse_motion: InputEventMouseMotion = event
				pointer_position = mouse_motion.position
			elif event is InputEventScreenDrag:
				var screen_drag: InputEventScreenDrag = event
				pointer_position = screen_drag.position
			drag_target.position = pointer_position - drag_start_pos

# ──────────────────────────────────────────────
# 命中检测
# D-pad：命中任意子按钮 → 返回容器（整体拖动）
# 右侧：命中哪个按钮 → 返回那个按钮（单独拖动）
# ──────────────────────────────────────────────
func _get_target_from_position(pos: Vector2) -> Node2D:
	# D-pad：检查子按钮的整体包围盒，命中则返回容器
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var container: Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		if _get_children_bounding_rect(container).has_point(pos):
			return container

	# 右侧按钮：逐个检测，返回命中的单个按钮
	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child: Node in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton:
				var btn: TouchScreenButton = child
				if _get_button_rect(btn).has_point(pos):
					return btn

	return null

# 根据 TouchScreenButton 的 shape 计算屏幕矩形
func _get_button_rect(btn: TouchScreenButton) -> Rect2:
	var half: Vector2 = Vector2(128.0, 128.0)
	var shape: Shape2D = btn.shape
	if shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = shape
		half = rect_shape.size * 0.5
	return Rect2(btn.global_position - half, half * 2.0)

# 容器内所有 TouchScreenButton 的联合包围盒
func _get_children_bounding_rect(container: Node2D) -> Rect2:
	var min_pos: Vector2 = Vector2(INF, INF)
	var max_pos: Vector2 = Vector2(-INF, -INF)
	for child: Node in container.get_children():
		if not child is TouchScreenButton:
			continue
		var btn: TouchScreenButton = child
		var r: Rect2 = _get_button_rect(btn)
		min_pos = Vector2(minf(min_pos.x, r.position.x), minf(min_pos.y, r.position.y))
		max_pos = Vector2(maxf(max_pos.x, r.end.x),      maxf(max_pos.y, r.end.y))
	if min_pos.x == INF:
		return Rect2(container.global_position - Vector2(300, 300), Vector2(600, 600))
	return Rect2(min_pos, max_pos - min_pos)

# ──────────────────────────────────────────────
# 存档：D-pad 存容器坐标；右侧按钮按 action 名各自存
# ──────────────────────────────────────────────
func _save_positions() -> void:
	if not game_config:
		return

	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var container: Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		game_config.set_value("mobile_layout", "dpad_position", var_to_str(container.position))

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child: Node in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton:
				var btn: TouchScreenButton = child
				if not btn.action.is_empty():
					game_config.set_value("mobile_layout", "btn_" + btn.action, var_to_str(btn.position))

	GameConfig.save()

# ──────────────────────────────────────────────
# 读档
# ──────────────────────────────────────────────
func _load_positions() -> void:
	if not game_config:
		return

	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var container: Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		var saved: String = game_config.get_value("mobile_layout", "dpad_position", "")
		if saved != "":
			var pos: Variant = str_to_var(saved)
			if pos is Vector2:
				container.position = pos

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child: Node in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton:
				var btn: TouchScreenButton = child
				if not btn.action.is_empty():
					var saved: String = game_config.get_value("mobile_layout", "btn_" + btn.action, "")
					if saved != "":
						var pos: Variant = str_to_var(saved)
						if pos is Vector2:
							btn.position = pos

# ──────────────────────────────────────────────
# 保存默认布局到config
# ──────────────────────────────────────────────
func _save_default_layout_to_config() -> void:
	if not game_config:
		return

	# 保存D-pad默认位置
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var container: Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		game_config.set_value("mobile_layout_default", "dpad_position", var_to_str(container.position))

	# 保存右侧按钮默认位置
	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child: Node in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton:
				var btn: TouchScreenButton = child
				if not btn.action.is_empty():
					game_config.set_value("mobile_layout_default", "btn_" + btn.action, var_to_str(btn.position))

	GameConfig.save()

# 还原默认布局（恢复到真正的默认位置）
# ──────────────────────────────────────────────
func _make_buttons_layout_default() -> void:
	# 优先从config中读取默认布局，如果没有则使用原始位置
	var use_default_from_config: bool = false
	
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var container: Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		var saved_default: String = game_config.get_value("mobile_layout_default", "dpad_position", "")
		if saved_default != "":
			var pos: Variant = str_to_var(saved_default)
			if pos is Vector2:
				container.position = pos
				use_default_from_config = true
		else:
			container.position = _original_dpad_pos

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child: Node in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton:
				var btn: TouchScreenButton = child
				if not btn.action.is_empty():
					var saved_default: String = game_config.get_value("mobile_layout_default", "btn_" + btn.action, "")
					if saved_default != "":
						var pos: Variant = str_to_var(saved_default)
						if pos is Vector2:
							btn.position = pos
							use_default_from_config = true
					else:
						if _original_button_positions.has(btn.action):
							btn.position = _original_button_positions[btn.action]

	# 清除用户自定义的移动布局配置（保留默认布局配置）
	if game_config.has_section("mobile_layout"):
		game_config.erase_section("mobile_layout")
	
	# 强制保存配置
	GameConfig.save()
	
	# 更新当前默认位置记录
	_capture_defaults()
	
	print("[%s] 重置按键布局：" % Time.get_time_string_from_system(), "使用配置中的默认布局" if use_default_from_config else "使用原始默认布局")