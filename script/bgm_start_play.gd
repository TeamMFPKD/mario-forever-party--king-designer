extends Node

func _ready() -> void:
	var bgm = get_tree().get_first_node_in_group("bgm") as AudioStreamPlayer
	if not bgm.playing:
		bgm.play()
