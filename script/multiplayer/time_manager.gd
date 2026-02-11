extends Node

@export var left_time_label : Label

var timer : Timer

func _ready() -> void:
	timer = TimerSingleton
	timer.timeout.connect(_on_timer_timeout)

func _process(_delta) -> void:
	left_time_label.text = str(ceil(timer.time_left))

func _on_timer_timeout() -> void:
	print("Timeout!")
