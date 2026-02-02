extends Node

@export var ani : AnimatedSprite2D
@export var rot_speed : float = 15.0

var direction : int

func _ready():
	direction = get_parent().get_meta("fireball_direction") as int

func _physics_process(delta):
	ani.rotation += rot_speed * delta * direction
