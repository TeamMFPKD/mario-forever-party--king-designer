extends VBoxContainer

signal result_list_updated

@export var result_list_scene: PackedScene

const RandomCaptureManagerType: GDScript = preload("res://script/multiplayer/random_capture/random_capture_manager.gd")

var multiplayer_manager: MultiplayerManager
var random_capture_manager: RandomCaptureManagerType
#var players

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.result_updated.connect(_on_result_list_updated)
	random_capture_manager = RandomCaptureManager

func _on_result_list_updated(players: Array) -> void:
	# Refresh list
	#players = multiplayer_manager.players

	# Clear
	for child: Node in get_children():
		child.free()

	# Re-add
	for player: Variant in players:
		var result_list_line: Node = result_list_scene.instantiate()

		var player_id: int = player["id"]
		var capture_rect: TextureRect = result_list_line.get_node("CaptureTextureRect") as TextureRect
		capture_rect.texture = random_capture_manager.get_capture(player_id)
		
		var player_name_label: Label = result_list_line.get_node("PlayerNameLabel") as Label
		player_name_label.text = str(player["name"])

		var level_cause_pass_label: Label = result_list_line.get_node("LevelCausePassLabel") as Label
		level_cause_pass_label.text = str(player["level_cause_pass"])

		var level_cause_death_label: Label = result_list_line.get_node("LevelCauseDeathLabel") as Label
		level_cause_death_label.text = str(player["level_cause_death"])

		var player_clear_rate: float = player["clear_rate"]
		var clear_rate_label: Label = result_list_line.get_node("ClearRateLabel") as Label
		clear_rate_label.text = str(round(player_clear_rate * 100000.0) / 1000.0) + "%"

		var level_pass_count_label: Label = result_list_line.get_node("LevelPassCountLabel") as Label
		level_pass_count_label.text = str(player["level_pass_count"])

		var score_label: Label = result_list_line.get_node("ScoreLabel") as Label
		score_label.text = str(player["score"])
		add_child(result_list_line)

	random_capture_manager.clear_captures()

	emit_signal("result_list_updated")
