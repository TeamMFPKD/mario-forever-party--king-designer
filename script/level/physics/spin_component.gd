extends Node

@export var path_to_sprite: NodePath = ".."
@export var rotation_speed: float = 40

var sprite: Node2D

func _ready():
	sprite = get_node(path_to_sprite) as Node2D

func _physics_process(delta: float) -> void:
	sprite.rotation += rotation_speed * delta
	