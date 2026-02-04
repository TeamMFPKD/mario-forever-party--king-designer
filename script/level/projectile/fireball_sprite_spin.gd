extends Node

@export var ani : AnimatedSprite2D
@export var rot_speed : float = 15.0

var direction : int = 1

func _ready():
	var parent = get_parent()
	if parent.has_meta("fireball_direction"):
		direction = get_parent().get_meta("fireball_direction") as int
	else:
		push_warning("Fireball direction not set!")

func _physics_process(delta):
	ani.rotation += rot_speed * delta * direction
