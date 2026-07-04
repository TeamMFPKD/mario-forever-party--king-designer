extends Node

signal goal_exists
signal none_goal_hint

var timer: Timer


func _ready() -> void:
	timer = get_tree().get_first_node_in_group("timer_singleton") as Timer


func _process(_delta: float) -> void:
	if ceil(timer.time_left) > 10:
		return

	var goals = get_tree().get_nodes_in_group("spawner_goal_gate")

	if goals.size() == 0:
		none_goal_hint.emit()
	else:
		goal_exists.emit()
		