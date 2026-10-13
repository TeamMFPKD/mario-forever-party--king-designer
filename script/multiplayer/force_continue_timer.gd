extends Timer

signal force_continue

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = MPManager
	if not multiplayer_manager.multiplayer.is_server():
		return
	timeout.connect(_on_timeout)

func _on_timeout() -> void:
	emit_signal("force_continue")
	