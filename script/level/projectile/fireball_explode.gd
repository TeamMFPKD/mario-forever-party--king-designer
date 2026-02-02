extends Node

@export var fireball : Node2D
@export var fireball_explode_scene : PackedScene

func explode() -> void:
	if fireball_explode_scene:
		var fireball_explode = fireball_explode_scene.instantiate() as Node2D
		fireball_explode.position = fireball.position
		fireball.add_sibling(fireball_explode)
	else:
		push_error("fireball_explode_scene is not set")
		