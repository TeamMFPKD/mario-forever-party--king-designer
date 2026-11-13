extends Camera2D

class_name LevelCamera

signal limit_changed(top: int, left: int, right: int, bottom: int)

@export var max_speed: float = 960.0

var speed: float = 0.0
var direction: Vector2 = Vector2.ZERO

var player: Node2D
var last_player_position: Vector2

const TELEPORT_THRESHOLD: float = 64.0

func _physics_process(delta: float) -> void:
	var is_in_level: bool = in_level_check()
	if is_in_level:
		if not player:
			player = get_tree().get_first_node_in_group("player")
			if not player:
				return
			position = player.position
			last_player_position = player.position
			reset_physics_interpolation()
			return
		if last_player_position.distance_to(player.position) > TELEPORT_THRESHOLD:
			position = player.position
			reset_physics_interpolation()
		last_player_position = player.position
		position = player.position
		return

	# 编辑模式下镜头由键鼠方向键 / WASD 驱动。
	# 手柄在场时 move_* 同时绑了 D-pad 和左摇杆，而这两者要留给
	# 「D-pad 控 UI 焦点」「摇杆控编辑光标」（见 docs/gamepad/README.md §6），
	# 所以手柄主导时镜头不再响应这些动作。
	direction = Vector2.ZERO
	if _keyboard_camera_enabled():
		if Input.is_action_pressed("move_up"):
			direction += Vector2.UP
			speed = max_speed
		if Input.is_action_pressed("move_down"):
			direction += Vector2.DOWN
			speed = max_speed
		if Input.is_action_pressed("move_left"):
			direction += Vector2.LEFT
			speed = max_speed
		if Input.is_action_pressed("move_right"):
			direction += Vector2.RIGHT
			speed = max_speed
	direction = direction.normalized()
	position += direction * speed * delta
	speed = 0.0

	position.x = clamp(position.x, limit_left + 320, limit_right - 320)
	position.y = clamp(position.y, limit_top + 240, limit_bottom - 240)

## 编辑模式下是否允许键盘/鼠标驱动镜头。
## 手柄主导时返回 false，把那几组输入让给 UI 导航和编辑光标。
##
## 这里直接读摇杆轴而不查 InputDevice autoload：
## autoload 的返回值是 Variant，本项目的 @warning_as_error 不允许把它
## 转成 bool，会直接编译失败。
const CAMERA_JOY_DEADZONE: float = 0.35

func _keyboard_camera_enabled() -> bool:
	var pads: PackedInt32Array = Input.get_connected_joypads()
	for device: int in pads:
		if absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_X)) > CAMERA_JOY_DEADZONE:
			return false
		if absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)) > CAMERA_JOY_DEADZONE:
			return false
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP) \
			or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN) \
			or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT) \
			or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
			return false
	return true


func set_limit_top(value: int) -> void:
	limit_top = min(value, limit_bottom - 480)
	emit_signal("limit_changed", limit_top, limit_left, limit_right, limit_bottom)

func set_limit_left(value: int) -> void:
	limit_left = min(value, limit_right - 640)
	emit_signal("limit_changed", limit_top, limit_left, limit_right, limit_bottom)

func set_limit_right(value: int) -> void:
	limit_right = max(value, limit_left + 640)
	emit_signal("limit_changed", limit_top, limit_left, limit_right, limit_bottom)

func set_limit_bottom(value: int) -> void:
	limit_bottom = max(value, limit_top + 480)
	emit_signal("limit_changed", limit_top, limit_left, limit_right, limit_bottom)

## 一次性应用四个边界（撤销 / 重做关卡尺寸时使用），只发一次 limit_changed。
## 约束与四个 set_limit_* 逐个调用一致：可视区最小 640 x 480。
func apply_limits(top: int, left: int, right: int, bottom: int) -> void:
	limit_top = top
	limit_left = left
	limit_right = right
	limit_bottom = bottom
	limit_top = min(limit_top, limit_bottom - 480)
	limit_left = min(limit_left, limit_right - 640)
	limit_right = max(limit_right, limit_left + 640)
	limit_bottom = max(limit_bottom, limit_top + 480)
	emit_signal("limit_changed", limit_top, limit_left, limit_right, limit_bottom)

func in_level_check() -> bool:
	var game_mode_node: GameMode = GameModeSingleton
	return game_mode_node.game_mode == GameMode.GameModeType.TEST \
	or game_mode_node.game_mode == GameMode.GameModeType.PLAY \
	or game_mode_node.game_mode == GameMode.GameModeType.HISTORY_PLAY \
	or GameMode.is_adventure()