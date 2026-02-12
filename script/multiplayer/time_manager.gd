extends Node

@export var left_time_label : Label

var timer : Timer

func _ready() -> void:
	timer = TimerSingleton
	if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.PLAY:
		left_time_label.visible = false
		return
	left_time_label.visible = true
	timer.timeout.connect(_on_timer_timeout)

func _process(_delta) -> void:
	left_time_label.text = str(int(ceil(timer.time_left)))

func _on_timer_timeout() -> void:
	print("Timeout!")
