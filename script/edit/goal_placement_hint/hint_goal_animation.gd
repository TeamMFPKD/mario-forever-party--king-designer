extends Node

@export var path_to_hint: NodePath = ".."

var hint: Control
var speed: float = 100
var timer: float = 0.0


func _ready():
	hint = get_node(path_to_hint)

func _process(delta: float):
	if not hint:
		return
		
	hint.position += Vector2(speed * delta, 0).rotated(hint.rotation)
	timer += delta
	speed = sin(timer * 10) * 100
