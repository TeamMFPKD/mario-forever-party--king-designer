extends BasicMovement

func _ready():
	if get_parent().has_meta("enemy_dead_direction"):
		var direction = get_parent().get_meta("enemy_dead_direction") as int
		if direction != 1:
			speed_x = 0 - speed_x
	super._ready()
	