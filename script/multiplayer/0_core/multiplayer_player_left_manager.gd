extends Node

@export var player_left_label_scene: PackedScene
@export var list_control_node: Control

var multiplayer_manager: MultiplayerManager
var players = []
var previous_players = []

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager")
	multiplayer_manager.players_updated.connect(_on_players_updated)
	multiplayer_manager.multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_players_updated() -> void:
	if previous_players.size() == 0:
		previous_players = players
	players = multiplayer_manager.players
	if players.size() != previous_players.size():
		_on_players_changed()
	previous_players = players

func _on_players_changed() -> void:
	# 只关注玩家离开的情况
	if players.size() < previous_players.size():
		# 找出离开的玩家
		for prev_player in previous_players:
			var found = false
			for player in players:
				if player.id == prev_player.id:
					found = true
					break
			if not found:
				var player_left_label = player_left_label_scene.instantiate() as Label
				player_left_label.text = tr(player_left_label.text).format({"player_name": prev_player.name})
				list_control_node.add_child(player_left_label)
				#print("[%s] [玩家离开通知器] 玩家 %s 离开了游戏" % [Time.get_time_string_from_system(), MPManager.format_player(prev_player.name, prev_player.id)])

func _on_server_disconnected() -> void:
	var player_left_label = player_left_label_scene.instantiate() as Label
	player_left_label.text = tr("与主机断开。")
	list_control_node.add_child(player_left_label)
