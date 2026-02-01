extends Node

var parent : Node2D

@export var time : int = 120
var timer : int = 0

func _ready() -> void:
	parent = get_parent() as Node2D

func _physics_process(delta: float) -> void:
	timer += 1
	if timer > time:
		parent.modulate.a -= 0.05
		if parent.modulate.a <= 0.0:
			parent.queue_free()
