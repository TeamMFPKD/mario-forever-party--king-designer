extends ControlVisibieSet

var mobile_control
var game_config
var is_dragging    := false
var drag_start_pos := Vector2.ZERO
var drag_target    : Node = null  # Node2D 容器（D-pad）或 TouchScreenButton（右侧单按钮）

# 用于 _make_buttons_layout_default，在加载存档前记录场景初始值
var _default_dpad_pos         := Vector2.ZERO
var _default_button_positions := {}  # action -> Vector2

func _ready():
	super._ready()
	mobile_control = get_tree().get_first_node_in_group("mobile_control")
	game_config = GameConfig
	_capture_defaults()  # 必须在 _load_positions 之前
	_load_positions()
	if control:
		control.gui_input.connect(_on_canvas_gui_input)

# ──────────────────────────────────────────────
# 记录场景原始默认位置（用于重置）
# ──────────────────────────────────────────────
func _capture_defaults() -> void:
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		_default_dpad_pos = mobile_control.control_d_pad.get_node("ControlDPad").position

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton and not child.action.is_empty():
				_default_button_positions[child.action] = child.position

# ──────────────────────────────────────────────
# 显示 / 隐藏
# ──────────────────────────────────────────────
func _set_visible():
	super._set_visible()
	mobile_control.show_mode = MobileControl.ShowModeType.SHOW

func _set_invisible():
	super._set_invisible()
	mobile_control.show_mode = MobileControl.ShowModeType.HIDE

# ──────────────────────────────────────────────
# 输入处理
# ──────────────────────────────────────────────
func _on_canvas_gui_input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			drag_target = _get_target_from_position(event.position)
			if drag_target:
				is_dragging    = true
				drag_start_pos = event.position - drag_target.position
		else:
			if is_dragging:
				is_dragging = false
				drag_target = null
				_save_positions()

	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if is_dragging and drag_target:
			drag_target.position = event.position - drag_start_pos

# ──────────────────────────────────────────────
# 命中检测
# D-pad：命中任意子按钮 → 返回容器（整体拖动）
# 右侧：命中哪个按钮 → 返回那个按钮（单独拖动）
# ──────────────────────────────────────────────
func _get_target_from_position(pos: Vector2) -> Node:
	# D-pad：检查子按钮的整体包围盒，命中则返回容器
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var container : Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		if _get_children_bounding_rect(container).has_point(pos):
			return container

	# 右侧按钮：逐个检测，返回命中的单个按钮
	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton:
				if _get_button_rect(child).has_point(pos):
					return child

	return null

# 根据 TouchScreenButton 的 shape 计算屏幕矩形
func _get_button_rect(btn: TouchScreenButton) -> Rect2:
	var half := Vector2(128.0, 128.0)
	if btn.shape is RectangleShape2D:
		half = btn.shape.size * 0.5
	return Rect2(btn.global_position - half, half * 2.0)

# 容器内所有 TouchScreenButton 的联合包围盒
func _get_children_bounding_rect(container: Node2D) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for child in container.get_children():
		if not child is TouchScreenButton:
			continue
		var r := _get_button_rect(child)
		min_pos = Vector2(min(min_pos.x, r.position.x), min(min_pos.y, r.position.y))
		max_pos = Vector2(max(max_pos.x, r.end.x),      max(max_pos.y, r.end.y))
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
		var container : Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		game_config.config.set_value("mobile_layout", "dpad_position", var_to_str(container.position))

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton and not child.action.is_empty():
				game_config.config.set_value("mobile_layout", "btn_" + child.action, var_to_str(child.position))

	game_config.save()

# ──────────────────────────────────────────────
# 读档
# ──────────────────────────────────────────────
func _load_positions() -> void:
	if not game_config:
		return

	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var container : Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		var saved = game_config.config.get_value("mobile_layout", "dpad_position", "")
		if saved != "":
			var pos = str_to_var(saved)
			if pos is Vector2:
				container.position = pos

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton and not child.action.is_empty():
				var saved = game_config.config.get_value("mobile_layout", "btn_" + child.action, "")
				if saved != "":
					var pos = str_to_var(saved)
					if pos is Vector2:
						child.position = pos

# ──────────────────────────────────────────────
# 还原默认布局（清除存档 + 恢复场景初始位置）
# ──────────────────────────────────────────────
func _make_buttons_layout_default() -> void:
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		mobile_control.control_d_pad.get_node("ControlDPad").position = _default_dpad_pos

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		for child in mobile_control.control_button.get_node("ControlButton").get_children():
			if child is TouchScreenButton and not child.action.is_empty():
				if _default_button_positions.has(child.action):
					child.position = _default_button_positions[child.action]

	if game_config.config.has_section("mobile_layout"):
		game_config.config.erase_section("mobile_layout")
	game_config.save()