extends Label

@export var timer: Timer

func _process(_delta: float) -> void:
	text = str(timer.time_left - timer.wait_time)
