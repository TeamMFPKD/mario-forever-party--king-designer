extends Node

@export var path_to_parent : NodePath = ".."
@export var fireball_explode_scene : PackedScene
@export var offset : Vector2 = Vector2(0, 0)

var parent : Node2D

func _ready() -> void:
	parent = get_node(path_to_parent) as Node2D

func explode() -> void:
	if fireball_explode_scene:
		var fireball_explode = fireball_explode_scene.instantiate() as Node2D
		fireball_explode.position = parent.position + offset
		parent.add_sibling(fireball_explode)
	else:
		push_error("explode_scene is not set")
		