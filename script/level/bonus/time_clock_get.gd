extends Node

signal time_clock_got

@export var time_to_increase: float = 3.0
@export var ani: Node2D

@export var time_clock_label_scene: PackedScene = preload("uid://du6kfdkecp8h0")
@export var add_time_color: Color = Color(0.25, 1.0, 0.25)
@export var sub_time_color: Color = Color(1.0, 0.25, 0.25)

var game_timer: Timer
var is_activated: bool = false
var parent: Node2D

func _ready() -> void:
	game_timer = get_tree().get_first_node_in_group("game_timer")
	parent = get_parent() as Node2D

func _on_time_clock_get() -> void:
	if is_activated:
		return
	if not game_timer:
		push_error("game_timer not found")
		return
	is_activated = true
	ani.visible = false
	emit_signal("time_clock_got")
	game_timer.wait_time = clampf(game_timer.time_left + time_to_increase, 0.02, 999.0)
	game_timer.start()
	create_time_clock_label()

func _on_all_process_finished() -> void:
	parent.queue_free()

func create_time_clock_label() -> void:
	var time_clock_label_node = time_clock_label_scene.instantiate() as Node2D
	var time_clock_label = time_clock_label_node.get_node("TimeClockLabel") as Label
	time_clock_label_node.position = parent.position
	time_clock_label.text = ("+" if time_to_increase >= 0 else "") + str(int(time_to_increase)) + "s"
	if time_to_increase >= 0:
		time_clock_label.self_modulate = add_time_color
	else:
		time_clock_label.self_modulate = sub_time_color
	parent.add_sibling(time_clock_label_node)
