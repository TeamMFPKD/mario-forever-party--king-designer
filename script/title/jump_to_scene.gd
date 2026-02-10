extends Node

@export var scene_uid : StringName

func jump_to_scene() -> void:
	get_tree().change_scene_to_file(scene_uid)
	
