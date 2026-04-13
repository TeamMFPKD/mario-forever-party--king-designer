extends Node

@export var ani_player : AnimationPlayer
@export var hint_label : Label

var timer : Timer

func _ready() -> void:
	timer = get_tree().get_first_node_in_group("timer_singleton") as Timer

func _process(_delta: float) -> void:
	if not hint_label:
		push_error("hint_label is not set")
		return
	hint_label.visible = false
	if ceil(timer.wait_time) > 10:
		return
	var goals = get_tree().get_nodes_in_group("spawner_goal_gate")
	if goals.size() == 0:
		if not ani_player:
			push_error("ani_player is not set")
			return
		hint_label.visible = true
		ani_player.play(&"new_animation")
