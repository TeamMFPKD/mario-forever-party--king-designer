extends Node

signal back_to_title

var multiplayer_manager : MultiplayerManager

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	if multiplayer_manager.back_to_title:
		multiplayer_manager.return_origin_player_data.rpc()
		emit_signal("back_to_title")
