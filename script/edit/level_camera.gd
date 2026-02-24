extends Camera2D

class_name LevelCamera

signal limit_changed(top: int, left: int, right: int, bottom: int)

@export var max_speed : float = 960.0

var speed : float = 0.0
var direction := Vector2.ZERO

var player

func _physics_process(delta: float) -> void:
	var is_in_level = in_level_check()
	if is_in_level:
		if not player:
			player = get_tree().get_first_node_in_group("player")
			if not player:
				return
			position = player.position
			reset_physics_interpolation()
			return
		position = player.position
		return

	direction = Vector2.ZERO
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

func set_limit_top(value):
	limit_top = min(value, limit_bottom - 480)
	emit_signal("limit_changed", limit_top, limit_left, limit_right, limit_bottom)

func set_limit_left(value):
	limit_left = min(value, limit_right - 640)
	emit_signal("limit_changed", limit_top, limit_left, limit_right, limit_bottom)

func set_limit_right(value):
	limit_right = max(value, limit_left + 640)
	emit_signal("limit_changed", limit_top, limit_left, limit_right, limit_bottom)

func set_limit_bottom(value):
	limit_bottom = max(value, limit_top + 480)
	emit_signal("limit_changed", limit_top, limit_left, limit_right, limit_bottom)

func in_level_check() -> bool:
	return GameModeSingleton.game_mode == GameModeSingleton.GameModeType.TEST \
	or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.PLAY \
	or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.HISTORY_PLAY