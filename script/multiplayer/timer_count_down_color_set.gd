extends Node

@export var warning_color : Color = Color.YELLOW
@export var path_to_label : NodePath = "../EditTimeLabel"

var timer : Timer
var time_label : Label

func _ready() -> void:
	timer = get_tree().get_first_node_in_group("timer_singleton")
	time_label = get_node(path_to_label)

func _process(_delta: float) -> void:
	if not timer:
		push_error("Timer not found")
		return
	if not time_label:
		push_error("Label not found")
		return
	if timer.time_left <= 10.0:
		time_label.self_modulate = warning_color
	else:
		time_label.self_modulate = Color.WHITE
