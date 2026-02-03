extends BasicMovement

signal jump_speed_set

func set_jump_speed():
	if move_object.is_on_floor():
		emit_signal("jump_speed_set")
	super.set_jump_speed()
	