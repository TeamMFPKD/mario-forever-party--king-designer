extends Node

@export var left_time_label: Label

var timer: Timer

func _ready() -> void:
	timer = TimerSingleton
	var game_mode: GameMode = GameModeSingleton as GameMode
	if game_mode.game_mode == GameMode.GameModeType.PLAY:
		left_time_label.visible = false
		return
	left_time_label.visible = true
	timer.timeout.connect(_on_timer_timeout)

func _process(_delta: float) -> void:
	left_time_label.text = str(ceili(timer.time_left))

func _on_timer_timeout() -> void:
	print("[%s] [time_manager.gd] Timeout!" % Time.get_time_string_from_system())