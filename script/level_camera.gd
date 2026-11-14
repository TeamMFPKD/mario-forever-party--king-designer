extends Camera2D

class_name LevelCamera

signal limit_changed(top: int, left: int, right: int, bottom: int)

@export var max_speed: float = 960.0
## 跟随玩家的平滑速度（每秒指数逼近）；0 = 原来的硬跟随。
## 只给观战相机打开，正常游玩 / 编辑保持原样。
@export var follow_smoothing_speed: float = 0.0

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
			# 关卡内瞬移 / 换观察目标：直接对齐，不要拖着相机飞过去。
			position = player.position
			reset_physics_interpolation()
		elif follow_smoothing_speed > 0.0:
			var weight: float = 1.0 - exp(-follow_smoothing_speed * delta)
			position = position.lerp(player.position, weight)
		else:
			position = player.position
		last_player_position = player.position
		return

	# 编辑模式下镜头由 CAMERA 组驱动：WASD（键盘）/ 右摇杆（手柄）；
	# 移动端再并上方向键 / 十字键，让屏幕虚拟方向键也能推镜头（见 edit_camera_axis）。
	#
	# 三套操作互不重叠（定义见 script/utils/input_groups.gd）：
	# IJKL / 左摇杆 = 虚拟鼠标，方向键 / 十字键 = UI 焦点，WASD / 右摇杆 = 镜头。
	# 移动端是唯一例外：没有键盘、UI 焦点导航整体关闭，方向键那组就空出来给镜头用。
	direction = InputGroups.edit_camera_axis()
	if direction != Vector2.ZERO:
		speed = max_speed
		direction = direction.normalized()
	position += direction * speed * delta
	speed = 0.0

	position.x = clamp(position.x, limit_left + 320, limit_right - 320)
	position.y = clamp(position.y, limit_top + 240, limit_bottom - 240)


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