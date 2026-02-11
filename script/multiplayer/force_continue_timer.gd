extends Timer

signal force_continue

var multiplayer_manager : MultiplayerManager

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	if not multiplayer_manager.multiplayer.is_server():
		return
	timeout.connect(_on_timeout)

func _on_timeout() -> void:
	emit_signal("force_continue")
	