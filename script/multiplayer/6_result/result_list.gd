extends VBoxContainer

signal result_list_updated

@export var result_list_scene: PackedScene

var multiplayer_manager: MultiplayerManager
var random_capture_manager
#var players

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.result_updated.connect(_on_result_list_updated)
	random_capture_manager = RandomCaptureManager

func _on_result_list_updated(players) -> void:
	# Refresh list
	#players = multiplayer_manager.players

	# Clear
	for child in get_children():
		child.free()

	# Re-add
	for player in players:
		var result_list_line = result_list_scene.instantiate()

		var capture_rect = result_list_line.get_node("CaptureTextureRect")
		capture_rect.texture = random_capture_manager.get_capture(player["id"])
		
		var player_name_label = result_list_line.get_node("PlayerNameLabel") as Label
		player_name_label.text = player["name"]

		var level_cause_pass_label = result_list_line.get_node("LevelCausePassLabel") as Label
		level_cause_pass_label.text = str(player["level_cause_pass"])

		var level_cause_death_label = result_list_line.get_node("LevelCauseDeathLabel") as Label
		level_cause_death_label.text = str(player["level_cause_death"])

		var clear_rate_label = result_list_line.get_node("ClearRateLabel") as Label
		clear_rate_label.text = str(round(player["clear_rate"] * 100000.0) / 1000.0) + "%"

		var level_pass_count_label = result_list_line.get_node("LevelPassCountLabel") as Label
		level_pass_count_label.text = str(player["level_pass_count"])

		var score_label = result_list_line.get_node("ScoreLabel") as Label
		score_label.text = str(player["score"])
		add_child(result_list_line)

	random_capture_manager.clear_captures()

	emit_signal("result_list_updated")
