extends VBoxContainer

@export var player_list_scene: PackedScene
@export var path_to_ready_sound_node: NodePath = "../ReadySound"

var multiplayer_manager: MultiplayerManager
var players: Array
var ready_sound_node: AudioStreamPlayer

func _ready() -> void:
	multiplayer_manager = MPManager
	multiplayer_manager.players_updated.connect(_on_players_updated)
	ready_sound_node = get_node(path_to_ready_sound_node) as AudioStreamPlayer

func _on_players_updated() -> void:
	# Refresh list
	players = multiplayer_manager.players

	# Clear
	for child: Node in get_children():
		child.free()

	# Re-add
	var player_number: int = 1
	for player: Variant in players:
		var player_list_line: Node = player_list_scene.instantiate()
		var player_id_label: Label = player_list_line.get_node("PlayerIdLabel") as Label
		player_id_label.text = str(player_number)

		player_number += 1

		var player_name_label: Label = player_list_line.get_node("PlayerNameLabel") as Label
		player_name_label.text = str(player["name"])

		var player_ready_node: Control = player_list_line.get_node("PlayerReady") as Control
		var is_ready: bool = player.is_ready_to_start
		player_ready_node.visible = is_ready
		if is_ready:
			ready_sound_node.play()
		add_child(player_list_line)
