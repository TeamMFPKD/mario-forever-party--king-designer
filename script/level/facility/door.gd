extends Node2D

class_name DoorComponent

@export var id: int = 0
@export var path_to_area: NodePath = ".."

var area: Area2D

func _ready() -> void:
	area = get_node(path_to_area) as Area2D
	area.set_meta("door_component", self)
	add_to_group("door")