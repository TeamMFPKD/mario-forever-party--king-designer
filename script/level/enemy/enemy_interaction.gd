extends Node

class_name EnemyInteraction

@export var enemy_interaction_component_meta: Array[StringName] = []

func _ready() -> void:
	var parent: Node = get_parent()
	for meta: StringName in enemy_interaction_component_meta:
		if has_meta(meta):
			parent.set_meta(meta, get_meta(meta))