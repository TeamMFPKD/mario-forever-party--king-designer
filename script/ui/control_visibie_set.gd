extends Node

class_name ControlVisibieSet

@export var path_to_control: NodePath = ".."

var control: Control

func _ready() -> void:
	control = get_node(path_to_control) as Control

func _set_visible() -> void:
	control.visible = true

func _set_invisible() -> void:
	control.visible = false
	
