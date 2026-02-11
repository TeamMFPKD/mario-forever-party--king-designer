extends Node

@export var level_data_node: LevelManager

var file_name: String = "user://mfmp_"
var date_time: String = "datetime"
var author: String = "author"

var multiplayer_manager : MultiplayerManager

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	if multiplayer_manager:
		date_time = multiplayer_manager.game_start_time
		var unique_id = OS.get_unique_id()
		unique_id = unique_id.replace("{", "")
		unique_id = unique_id.substr(0, 5)
		author = multiplayer_manager.player_name + "_" + unique_id
	file_name += date_time + "_" + author + ".lvl"

func _on_save_button_pressed() -> void:
	var level_data_json = level_data_node.get_level_data_json()
	print("save path: ", file_name)
	save_to_level(level_data_json)
	print("Level saved.")
	if multiplayer_manager:
		multiplayer_manager.player.level_file_name = file_name
		multiplayer_manager.player.level_data = level_data_json

func save_to_level(content):
	var file = FileAccess.open(file_name, FileAccess.WRITE)
	var err = FileAccess.get_open_error()
	if err != OK:
		print("Error saving file:", err)
		return
	file.store_string(content)
	file.close()
