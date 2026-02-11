extends Node

var multiplayer_manager : MultiplayerManager

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager

func lets_play_together():
	print("Lets play together")
	
	multiplayer_manager.lets_play_together.rpc()
