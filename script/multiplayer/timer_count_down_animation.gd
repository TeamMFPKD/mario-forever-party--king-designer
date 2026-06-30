extends Node

signal new_second_passed(animation_name: StringName)

@export var path_to_animation: NodePath = "../EditTimeLabel"
@export var warning_phase: int = 10

var timer: Timer
var previous_second: int = -1
var current_second: int = -1

func _ready() -> void:
	timer = get_tree().get_first_node_in_group("timer_singleton")
	current_second = int(ceil(timer.time_left))
	previous_second = current_second

func _process(_delta: float) -> void:
	current_second = int(ceil(timer.time_left))
	if current_second != previous_second and current_second <= warning_phase:
		previous_second = current_second
		emit_signal("new_second_passed", &"count_down_hint")
