extends Node

@export var show_mode := MobileControl.ShowModeType.SHOW

var mobile_control : MobileControl

func _ready() -> void:
	mobile_control = get_tree().get_first_node_in_group("mobile_control")
	mobile_control.show_mode = show_mode
	
