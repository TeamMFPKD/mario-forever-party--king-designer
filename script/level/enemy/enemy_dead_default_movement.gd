extends BasicMovement

func _ready() -> void:
	if get_parent().has_meta("enemy_dead_direction"):
		var direction: int = get_parent().get_meta("enemy_dead_direction")
		if direction != 1:
			speed_x = 0 - speed_x
	super._ready()