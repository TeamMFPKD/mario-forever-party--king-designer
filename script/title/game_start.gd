extends Node

@export var jump_to_scene_node : Node

func _on_game_start() -> void:
	jump_to_scene_node.jump_to_scene()
	