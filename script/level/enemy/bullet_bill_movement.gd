extends BasicMovement

func _ready() -> void:
	super._ready()
	if move_object.has_meta("bill_direction"):
		speed_x = abs(speed_x) if (move_object.get_meta("bill_direction") as int) == 1 else -abs(speed_x)

func exit_pipe() -> void:
	match pipe_moving_dir:
		PipeMoveDirection.LEFT:
			previous_speed_x = -abs(previous_speed_x)
		PipeMoveDirection.RIGHT:
			previous_speed_x = abs(previous_speed_x)
	super.exit_pipe()