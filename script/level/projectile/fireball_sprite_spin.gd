extends Node

@export var ani: AnimatedSprite2D
@export var rot_speed: float = 15.0

var direction: int = 1

func _ready() -> void:
	var parent: Node = get_parent()
	if parent.has_meta("fireball_direction"):
		direction = get_parent().get_meta("fireball_direction")
	else:
		push_warning("Fireball direction not set!")

func _physics_process(delta: float) -> void:
	ani.rotation += rot_speed * delta * direction
