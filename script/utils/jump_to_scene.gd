extends Node

@export var scene_uid: StringName

func jump_to_scene() -> void:
	GlobalTransition.change_scene_to_file(String(scene_uid))
	