extends BasicMovement

class_name PlatformFallMovement

@export var fall_gravity: float = 300

var activated : bool = false

func _ready() -> void:
	super._ready()
	move_object.set_meta("platform_fall_movement", self)

func fall() -> void:
	if activated:
		return
	activated = true
	print("fall")
	gravity = fall_gravity
