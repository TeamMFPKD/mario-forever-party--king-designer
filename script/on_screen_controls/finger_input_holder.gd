@tool
extends Control

@export var touch_button: TouchScreenButton

var shape: Shape2D


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	shape = touch_button.get_shape()
	if not shape is RectangleShape2D:
		push_error("TouchScreenButton's shape is not a RectangleShape2D.")
		return
	var rect_shape: RectangleShape2D = shape
	size = rect_shape.size
	position = -size / 2