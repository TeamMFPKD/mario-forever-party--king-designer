class_name InputGroups
extends RefCounted

## 三套方向控制的封装。
##
## | 组 | 键盘 | 手柄 | 用途 |
## |---|---|---|---|
## | POINTER | IJKL | 左摇杆 | 移动虚拟鼠标 |
## | FOCUS | 方向键 | 十字键 D-pad | 操作 UI 焦点（有玩家时让给角色） |
## | CAMERA | WASD | 右摇杆 | 移动镜头 |
##
## 键盘与摇杆**全部**定义在 project.godot 的 `[input]` 段（`ui_cursor_*` /
## `ui_camera_*` / `ui_focus_*`），所以设置页能读、能改键，改完这里自动跟着变。
## 摇杆轴和键盘同属一个 action，`Input.get_vector` 天然把两者合到一起。
##
## 场景限制只有一条：PLAY / HISTORY_PLAY / TEST / ADVENTURE 里方向键与十字键归角色，
## 其余场合三组各管各的。

const JOY_DEADZONE: float = 0.2

const CURSOR_ACTIONS: Array[String] = [
	"ui_cursor_left", "ui_cursor_right", "ui_cursor_up", "ui_cursor_down",
]
const CAMERA_ACTIONS: Array[String] = [
	"ui_camera_left", "ui_camera_right", "ui_camera_up", "ui_camera_down",
]
const FOCUS_ACTIONS: Array[String] = [
	"ui_focus_left", "ui_focus_right", "ui_focus_up", "ui_focus_down",
]

enum Group {
	NONE,
	FOCUS,
	POINTER,
	CAMERA,
}


## POINTER 组：IJKL + 左摇杆。
static func pointer_axis() -> Vector2:
	return Input.get_vector(
		"ui_cursor_left", "ui_cursor_right", "ui_cursor_up", "ui_cursor_down"
	)


## FOCUS 组：方向键 + 十字键。
static func focus_axis() -> Vector2:
	return Input.get_vector("ui_focus_left", "ui_focus_right", "ui_focus_up", "ui_focus_down")


## CAMERA 组：WASD + 右摇杆。
static func camera_axis() -> Vector2:
	return Input.get_vector(
		"ui_camera_left", "ui_camera_right", "ui_camera_up", "ui_camera_down"
	)


## 判断这次事件属于哪一组。只认"开始动作"（按下 / 推杆超过死区）。
##
## 全部走各自专属的 action，所以设置页改键（包括绑摇杆轴）之后这里自动跟随。
static func classify(event: InputEvent) -> Group:
	if event is InputEventJoypadMotion:
		# 摇杆轴事件没有 pressed 语义，只按死区过滤
		var motion: InputEventJoypadMotion = event
		if absf(motion.axis_value) < JOY_DEADZONE:
			return Group.NONE
	elif event.is_echo() or not event.is_pressed():
		return Group.NONE
	if _matches_any(event, CURSOR_ACTIONS):
		return Group.POINTER
	if _matches_any(event, CAMERA_ACTIONS):
		return Group.CAMERA
	if _matches_any(event, FOCUS_ACTIONS):
		return Group.FOCUS
	return Group.NONE


static func _matches_any(event: InputEvent, actions: Array[String]) -> bool:
	for action: String in actions:
		if event.is_action_pressed(action):
			return true
	return false
