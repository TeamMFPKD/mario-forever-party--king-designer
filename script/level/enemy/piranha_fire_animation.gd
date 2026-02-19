extends Node

@export var path_to_parent : NodePath = ".."
@export var path_to_ani : NodePath = "../AnimatedSprite2D"

var ani : AnimatedSprite2D
var parent : Node2D
var player : Node2D

func _ready():
	parent = get_node(path_to_parent)
	ani = get_node(path_to_ani)
	var fc = func():
		player = get_tree().get_first_node_in_group("player") as Node2D
	fc.call_deferred()
	
func _physics_process(_delta: float):
	var look_up : bool = player.position.y > parent.position.y
	if ani.flip_v:
		look_up = not look_up
	ani.animation = "default" if look_up else "look_up"

	ani.flip_h = player.position.x < parent.position.x
