extends ControlVisibieSet

var mobile_control
var game_config
var is_dragging := false
var drag_start_pos := Vector2.ZERO
var drag_target : Node2D = null

func _ready():
	super._ready()
	mobile_control = get_tree().get_first_node_in_group("mobile_control")
	game_config = GameConfig
	_load_positions()
	if control:
		control.gui_input.connect(_on_canvas_gui_input)

func _set_visible():
	super._set_visible()
	mobile_control.show_mode = MobileControl.ShowModeType.SHOW

func _set_invisible():
	super._set_invisible()
	mobile_control.show_mode = MobileControl.ShowModeType.HIDE

func _on_canvas_gui_input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			drag_target = _get_target_from_position(event.position)
			if drag_target:
				is_dragging = true
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
# 命中检测：根据子按钮的实际 shape 动态计算包围盒
# 替代原来硬编码的 ±300px 固定矩形，解决上方按钮点不到的问题
# ──────────────────────────────────────────────
func _get_bounding_rect(container: Node2D) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)

	for child in container.get_children():
		if not child is TouchScreenButton:
			continue
		var half := Vector2(128.0, 128.0)  # 默认半尺寸
		if child.shape is RectangleShape2D:
			half = child.shape.size * 0.5
		var gp : Vector2 = child.global_position
		min_pos = Vector2(min(min_pos.x, gp.x - half.x), min(min_pos.y, gp.y - half.y))
		max_pos = Vector2(max(max_pos.x, gp.x + half.x), max(max_pos.y, gp.y + half.y))

	# 无子按钮时退回保守矩形
	if min_pos.x == INF:
		return Rect2(container.global_position - Vector2(300, 300), Vector2(600, 600))

	return Rect2(min_pos, max_pos - min_pos)

func _get_target_from_position(pos: Vector2) -> Node2D:
	# D-pad 区域
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var container : Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		if _get_bounding_rect(container).has_point(pos):
			return container

	# 按钮区域
	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		var container : Node2D = mobile_control.control_button.get_node("ControlButton")
		if _get_bounding_rect(container).has_point(pos):
			return container

	return null

# ──────────────────────────────────────────────
# 存档：str() → var_to_str()，与 str_to_var() 格式匹配
# 原来用 str() 序列化，输出 "(x, y)" 格式，str_to_var() 无法识别
# ──────────────────────────────────────────────
func _save_positions():
	if not game_config:
		return

	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var container : Node2D = mobile_control.control_d_pad.get_node("ControlDPad")
		game_config.config.set_value("mobile_layout", "dpad_position", var_to_str(container.position))

	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		var container : Node2D = mobile_control.control_button.get_node("ControlButton")
		game_config.config.set_value("mobile_layout", "buttons_position", var_to_str(container.position))

	game_config.save()

func _load_positions():
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
		var container : Node2D = mobile_control.control_button.get_node("ControlButton")
		var saved = game_config.config.get_value("mobile_layout", "buttons_position", "")
		if saved != "":
			var pos = str_to_var(saved)
			if pos is Vector2:
				container.position = pos