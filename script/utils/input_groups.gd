class_name InputGroups
extends RefCounted

## 三套方向控制的封装。
##
## | 组 | 键盘 | 手柄 |
## |---|---|---|
## | POINTER | WASD | 左摇杆 |
## | FOCUS | 方向键 | 十字键 D-pad |
## | SCROLL | IJKL | 右摇杆 |
##
## 用途按场景分配（不是固定的一套管 UI、一套管角色）：
##
## | 场景 | POINTER 组 | FOCUS 组 | SCROLL 组 |
## |---|---|---|---|
## | 菜单 / 标题 / 列表 | 虚拟鼠标 | UI 焦点 | 滚动列表 |
## | 编辑室 edit.tscn | 镜头移动 | UI 焦点 | 滚动列表 |
## | PLAY / HISTORY_PLAY | UI（虚拟鼠标） | 角色移动 | 滚动列表 |
##
## 为什么能这样分：`move_*` 里已移除 WASD（只留方向键 + 十字键 + 左摇杆给角色），
## 而 UI 焦点改用独立的 `ui_focus_*`（只有方向键 + 十字键，不含摇杆）。
## 两套摇杆靠轴编号区分：左摇杆 axis 0/1 → POINTER，右摇杆 axis 2/3 → SCROLL。

const JOY_DEADZONE: float = 0.2

enum Group {
	NONE,
	FOCUS,
	POINTER,
	SCROLL,
}


## POINTER 组的方向向量：WASD 物理键 + 左摇杆轴。
## 同时按时归一化，避免斜向比直线快。
static func pointer_axis() -> Vector2:
	var axis: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		axis.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		axis.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		axis.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		axis.y += 1.0
	for device: int in Input.get_connected_joypads():
		var joy: Vector2 = Vector2(
			Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		)
		if joy.length() >= JOY_DEADZONE:
			axis += joy
	if axis.length() > 1.0:
		axis = axis.normalized()
	return axis


## FOCUS 组的方向向量：方向键 + 十字键（`ui_focus_*`，不含摇杆）。
static func focus_axis() -> Vector2:
	return Input.get_vector("ui_focus_left", "ui_focus_right", "ui_focus_up", "ui_focus_down")


## SCROLL 组的方向向量：IJKL 物理键 + 右摇杆轴。
## I 上 / K 下 / J 左 / L 右，与右摇杆推杆方向一致（y 为正表示往下滚）。
static func scroll_axis() -> Vector2:
	var axis: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_J):
		axis.x -= 1.0
	if Input.is_physical_key_pressed(KEY_L):
		axis.x += 1.0
	if Input.is_physical_key_pressed(KEY_I):
		axis.y -= 1.0
	if Input.is_physical_key_pressed(KEY_K):
		axis.y += 1.0
	for device: int in Input.get_connected_joypads():
		var joy: Vector2 = Vector2(
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		)
		if joy.length() >= JOY_DEADZONE:
			axis += joy
	if axis.length() > 1.0:
		axis = axis.normalized()
	return axis


## 判断这次事件属于哪一组。只认"开始动作"（按下 / 推杆超过死区）。
##
## 不能靠 action 区分：`ui_*` 与 `move_*` 都同时绑了方向键、十字键和左摇杆。
## 只能看事件类型（按钮 vs 摇杆轴）和键盘的 physical_keycode。
static func classify(event: InputEvent) -> Group:
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		if absf(motion.axis_value) < JOY_DEADZONE:
			return Group.NONE
		var axis: int = int(motion.axis)
		if axis == int(JOY_AXIS_LEFT_X) or axis == int(JOY_AXIS_LEFT_Y):
			return Group.POINTER
		if axis == int(JOY_AXIS_RIGHT_X) or axis == int(JOY_AXIS_RIGHT_Y):
			return Group.SCROLL
		return Group.NONE
	if event is InputEventJoypadButton:
		var joy_button: InputEventJoypadButton = event
		if not joy_button.pressed:
			return Group.NONE
		var index: int = int(joy_button.button_index)
		if index >= int(JOY_BUTTON_DPAD_UP) and index <= int(JOY_BUTTON_DPAD_RIGHT):
			return Group.FOCUS
		return Group.NONE
	if event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed or key.echo:
			return Group.NONE
		var code: Key = key.physical_keycode
		if code == KEY_UP or code == KEY_DOWN or code == KEY_LEFT or code == KEY_RIGHT:
			return Group.FOCUS
		if code == KEY_W or code == KEY_A or code == KEY_S or code == KEY_D:
			return Group.POINTER
		if code == KEY_I or code == KEY_J or code == KEY_K or code == KEY_L:
			return Group.SCROLL
		return Group.NONE
	return Group.NONE
