extends BasicMovement


func _ready() -> void:
	super._ready()
	origin_scale = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)

	speed_x = move_toward(speed_x, 0.0, 0.8 * 60)

	move_object.scale.x = move_toward(move_object.scale.x, 0.0, 0.1)
	move_object.scale.y = move_toward(move_object.scale.y, 0.0, 0.1)
	
	if move_object.scale.is_zero_approx():
		queue_free()