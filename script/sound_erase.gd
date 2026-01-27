extends AudioStreamPlayer

func _ready() -> void:
	var level_control = get_tree().get_first_node_in_group("level_control") as LevelControl
	if level_control:
		level_control.play_sound_erase.connect(_on_play_sound_erase)

func _on_play_sound_erase() -> void:
	if not is_playing():
		play()
		