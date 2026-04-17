extends BasicMovement

signal explode

func _ready():
	super._ready()
	if get_parent().has_meta("fireball_direction"):
		var direction = get_parent().get_meta("fireball_direction") as int
		if direction != 1:
			speed_x = 0 - speed_x

func _physics_process(delta):
	super._physics_process(delta)
	if move_object.is_on_wall():
		emit_signal("explode")
		move_object.queue_free()
		
