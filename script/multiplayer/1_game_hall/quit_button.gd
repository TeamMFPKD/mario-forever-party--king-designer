extends Button

var multiplayer_manager: MultiplayerManager

func _ready():
	pressed.connect(_on_pressed)
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager

func _on_pressed():
	if multiplayer_manager:
		multiplayer_manager.disconnect_and_cleanup("主动退出")