extends ContinuousAudioStream

@export var sound_effect : bool:
	set(value):
		sound_effect = value
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Edit"), 0, sound_effect)

func _ready() -> void:
	# 初始化触发一次 set 方法
	sound_effect = sound_effect
	var game_mode = get_tree().get_first_node_in_group("game_mode") as GameMode
	game_mode.mode_set_to_edit.connect(_game_mode_changed_to_edit)
	game_mode.mode_set_to_test.connect(_game_mode_changed_to_play)
	game_mode.mode_set_to_play.connect(_game_mode_changed_to_play)

func _game_mode_changed_to_edit() -> void:
	sound_effect = true

func _game_mode_changed_to_play() -> void:
	sound_effect = false
	