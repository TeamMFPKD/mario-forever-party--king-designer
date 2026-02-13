extends Button

signal back_to_title

var multiplayer_manager : MultiplayerManager

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if multiplayer_manager.multiplayer.is_server():
		back_to_title_together.rpc()
	emit_signal("back_to_title")

@rpc("authority", "call_remote")
func back_to_title_together() -> void:
	emit_signal("back_to_title")
