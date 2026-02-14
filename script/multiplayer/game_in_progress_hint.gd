extends MarginContainer

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.game_in_progress_hint.connect(_on_game_in_progress_hint)

func _on_game_in_progress_hint() -> void:
	visible = true
