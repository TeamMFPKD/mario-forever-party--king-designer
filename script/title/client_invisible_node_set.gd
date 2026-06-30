extends Node

@export var invisible_node_set: Array[Node]

func _on_nodes_visible_set() -> void:
	for node in invisible_node_set:
		node.visible = true

func _on_nodes_invisible_set() -> void:
	for node in invisible_node_set:
		node.visible = false
		