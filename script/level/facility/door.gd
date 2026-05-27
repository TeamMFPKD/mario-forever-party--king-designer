extends Node2D

class_name DoorComponent

@export var id: int = 0
@export var path_to_area: NodePath = ".."
@export var path_to_ani: NodePath = "../../AnimatedSprite2D"

var area: Area2D
var ani: AnimatedSprite2D

func _ready() -> void:
	area = get_node(path_to_area) as Area2D
	area.set_meta("door_component", self)
	add_to_group("door")
	ani = get_node(path_to_ani) as AnimatedSprite2D
	ani.animation_finished.connect(_on_animation_finished)

func play_animation_enter() -> void:
	ani.play("enter")

func play_animation_exit() -> void:
	ani.play("exit")

func _on_animation_finished(animation: String) -> void:
	if animation == "exit":
		ani.play("default")