extends Node

@export var play: bool
@export var sound_effect: bool

func _ready() -> void:
	var bgm = get_tree().get_first_node_in_group("bgm") as BGM
	bgm.sound_effect = sound_effect
	if not bgm.playing and play:
		bgm.play()
	if not play:
		bgm.stop()
