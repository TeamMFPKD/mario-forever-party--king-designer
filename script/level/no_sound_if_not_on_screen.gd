extends Node

signal play_sound_pipe_in
signal play_sound_pipe_out

@export var is_on_screen_node : VisibleOnScreenNotifier2D
@export var basic_movement : BasicMovement

var is_on_screen : bool = false

func _play_sound_pipe_in() -> void:
	if not is_on_screen:
		return
	emit_signal("play_sound_pipe_in")

func _play_sound_pipe_out() -> void:
	if not is_on_screen:
		return
	emit_signal("play_sound_pipe_out")

func _physics_process(_delta: float) -> void:
	if not basic_movement:
		print("is_node_on_screen: basic_movement is null")
		return
	if not basic_movement.move_object:
		print("is_node_on_screen: move_object is null")
		return
	is_on_screen_node.global_position = basic_movement.move_object.global_position
	is_on_screen = is_on_screen_node.is_on_screen()
