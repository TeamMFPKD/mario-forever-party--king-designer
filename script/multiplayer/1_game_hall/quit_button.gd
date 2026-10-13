extends Button

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = MPManager
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	multiplayer_manager.disconnect_and_cleanup("主动退出")