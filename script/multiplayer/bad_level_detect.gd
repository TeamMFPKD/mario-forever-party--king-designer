extends Node

signal trigger_bad_level
signal skip_bad_level

var is_bad_level : bool = false

func _on_timeout():
	bad_level_check()

func bad_level_check():
	var player = get_tree().get_first_node_in_group("player") as Node2D
	is_bad_level = true if not player else false

	if not is_bad_level:
		return
	emit_signal("trigger_bad_level")

func _on_force_continue_button_pressed():
	bad_level_process()

func bad_level_process():
	print("[%s] 手动跳过坏关" % Time.get_time_string_from_system())
	emit_signal("skip_bad_level")