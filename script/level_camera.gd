extends Camera2D

@export var max_speed : float = 16.0

var speed : float = 0.0
var direction := Vector2.ZERO

func _physics_process(delta: float) -> void:
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
	position += direction * speed
	speed = 0.0

	position.x = clamp(position.x, limit_left + 320, limit_right - 320)
	position.y = clamp(position.y, limit_top + 240, limit_bottom - 240)
