extends Node

var is_played: bool = false

func _ready() -> void:
	var fc = func():
		is_played = true
	fc.call_deferred()