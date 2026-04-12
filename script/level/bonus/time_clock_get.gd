extends Node

signal time_clock_got

@export var time_to_increase : float = 3.0
@export var ani : Node2D

var game_timer : Timer
var is_activated : bool = false

func _ready() -> void:
	game_timer = get_tree().get_first_node_in_group("game_timer")

func _on_time_clock_get() -> void:
	print("Player entered time clock.")
	if is_activated:
		return
	print("Player entered not activated time clock.")
	if not game_timer:
		push_error("game_timer not found")
		return
	print("Time should be increased.")
	is_activated = true
	ani.visible = false
	emit_signal("time_clock_got")
	game_timer.wait_time = clampf(game_timer.time_left + time_to_increase, 0.02, 999.0)
	game_timer.start()

func _on_all_process_finished() -> void:
	get_parent().queue_free()
