extends Node

signal game_time_hud_visible

@export var game_timer: Timer
@export var game_time_label : Label

func _ready() -> void:
	var game_mode = GameModeSingleton
	if game_mode.game_mode == GameModeSingleton.GameModeType.PLAY:
		emit_signal("game_time_hud_visible")

func _process(_delta: float) -> void:
	game_time_label.text = str(int(game_timer.time_left))
