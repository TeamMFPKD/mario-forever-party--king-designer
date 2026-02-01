extends Node

@export var path_to_parent : NodePath = ".."
@export var rotation_speed : float = 0.01

var parent : Node2D

func _ready():
	parent = get_node(path_to_parent) as Node2D

func _physics_process(delta: float) -> void:
	parent.rotation += rotation_speed * delta
	