extends MarginContainer

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = MPManager
	multiplayer_manager.game_in_progress_hint.connect(_on_game_in_progress_hint)

func _on_game_in_progress_hint() -> void:
	visible = true
