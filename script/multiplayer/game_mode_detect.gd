extends Node

signal game_time_hud_invisible

func _ready() -> void:
	var game_mode = GameModeSingleton
	if game_mode.game_mode == GameModeSingleton.GameModeType.PLAY:
		emit_signal("game_time_hud_invisible")
		