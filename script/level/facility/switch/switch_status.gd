class_name SwitchStatus

extends Node

signal switched
signal changed_to_on
signal changed_to_off

@export var is_on : bool = true:
	set(value):
		is_on = value
		if is_on:
			emit_signal("changed_to_on")
		else:
			emit_signal("changed_to_off")
		emit_signal("switched")
	get():
		return is_on
