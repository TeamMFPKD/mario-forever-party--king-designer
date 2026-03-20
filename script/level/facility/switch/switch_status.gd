class_name SwitchStatus
extends Node

signal switched
signal changed_to_on
signal changed_to_off

var _switched_this_physics_frame: bool = false

@export var is_on: bool = true:
	set(value):
		if _switched_this_physics_frame:
			return
		_switched_this_physics_frame = true
		is_on = value
		if is_on:
			emit_signal("changed_to_on")
		else:
			emit_signal("changed_to_off")
		emit_signal("switched")
	get():
		return is_on

func _physics_process(_delta: float) -> void:
	_switched_this_physics_frame = false
	