extends VBoxContainer

@export var result_list_scene : PackedScene

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
	for player in players:
		var player_list_line = result_list_scene.instantiate()
		
		var player_name_label = player_list_line.get_node("PlayerNameLabel") as Label
		player_name_label.text = player["name"]
		add_child(player_list_line)

		var level_cause_pass_label = player_list_line.get_node("LevelCausePassLabel") as Label
		level_cause_pass_label.text = player["level_cause_pass"]
		add_child(player_list_line)

		var level_cause_death_label = player_list_line.get_node("LevelCauseDeathLabel") as Label
		level_cause_death_label.text = player["level_cause_death"]
		add_child(player_list_line)

		var clear_rate_label = player_list_line.get_node("ClearRateLabel") as Label
		clear_rate_label.text = player["clear_rate"]
		add_child(player_list_line)

		var level_pass_count_label = player_list_line.get_node("LevelPassCountLabel") as Label
		level_pass_count_label.text = player["level_pass_count"]
		add_child(player_list_line)

		var score_label = player_list_line.get_node("ScoreLabel") as Label
		score_label.text = player["score"]
		add_child(player_list_line)
