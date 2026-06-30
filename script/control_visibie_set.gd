extends Node

class_name ControlVisibieSet

@export var path_to_control: NodePath = ".."

var control: Control

func _ready():
	control = get_node(path_to_control) as Control

func _set_visible():
	control.visible = true

func _set_invisible():
	control.visible = false
	
