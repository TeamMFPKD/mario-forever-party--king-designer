extends Node

signal jump_to_scene
signal play_animation

var edit_timer: Timer

func _ready() -> void:
	if not OS.has_feature("editor"):
		emit_signal("play_animation")
		return
	_start_edit_timer()
	emit_signal("jump_to_scene")

func _start_edit_timer() -> void:
	edit_timer = get_tree().get_first_node_in_group("timer_singleton") as Timer
	edit_timer.start()
