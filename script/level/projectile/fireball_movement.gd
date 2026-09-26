extends BasicMovement

signal explode

func _ready() -> void:
	super._ready()
	crushed_at.connect(_on_crushed)
	if get_parent().has_meta("fireball_direction"):
		var direction: int = get_parent().get_meta("fireball_direction")
		if direction != 1:
			speed_x = 0 - speed_x

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if move_object.is_on_wall():
		emit_signal("explode")
		move_object.queue_free()
		
func _on_crushed(_pos: Vector2) -> void:
	emit_signal("explode")
	move_object.queue_free()
