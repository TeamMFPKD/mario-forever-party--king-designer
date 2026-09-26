extends Node

var is_played: bool = false

func _ready() -> void:
	var fc: Callable = func() -> void:
		is_played = true
	fc.call_deferred()