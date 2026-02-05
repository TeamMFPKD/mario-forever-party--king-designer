extends BasicMovement

func _ready() -> void:
	super._ready()
	if move_object.has_meta("bill_direction"):
		speed_x = abs(speed_x) if (move_object.get_meta("bill_direction") as int) == 1 else -abs(speed_x)
		
