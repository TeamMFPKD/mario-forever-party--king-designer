extends BasicMovement

signal beetroot_bounce

func _ready():
	super._ready()
	if get_parent().has_meta("beetroot_direction"):
		var direction = get_parent().get_meta("beetroot_direction") as int
		if direction != 1:
			speed_x = 0 - speed_x

func _physics_process(delta):
	super._physics_process(delta)
	if move_object.is_on_wall():
		emit_signal("beetroot_bounce")
		speed_y = jump_speed
		
func set_jump_speed() -> void:
	if move_object.is_on_floor():
		speed_y = min(0.0, jump_speed)
		emit_signal("beetroot_bounce")
		