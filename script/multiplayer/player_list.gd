extends VBoxContainer

@export var player_list_scene : PackedScene

var multiplayer_manager : MultiplayerManager
var players

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.players_updated.connect(_on_players_updated)

func _on_players_updated() -> void:
	# Refresh list
	players = multiplayer_manager.players

	# Clear
	for child in get_children():
		child.free()

	# Re-add
	var player_number = 1
	for player in players:
		var player_list_line = player_list_scene.instantiate()
		var player_id_label = player_list_line.get_node("PlayerIdLabel") as Label
		player_id_label.text = str(player_number)

		player_number += 1

		var player_name_label = player_list_line.get_node("PlayerNameLabel") as Label
		player_name_label.text = player["name"]
		add_child(player_list_line)
