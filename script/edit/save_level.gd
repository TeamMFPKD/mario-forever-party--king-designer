extends Node

@export var level_data_node: LevelManager

var file_name: String = "user://mfmp_"
var date_time: String = "datetime"
var author: String = "author"

func _ready() -> void:
	if MPManager:
		date_time = MPManager.game_start_time
		var unique_id = OS.get_unique_id()
		unique_id = unique_id.replace("{", "")
		unique_id = unique_id.substr(0, 5)
		author = MPManager.player_name + "_" + unique_id
	file_name += date_time + "_" + author + ".lvl"

func _on_save_button_pressed() -> void:
	var level_data_json = level_data_node.get_level_data_json()
	print("save path: ", file_name)
	save_to_level(level_data_json)
	print("Level saved.")

func save_to_level(content):
	var file = FileAccess.open(file_name, FileAccess.WRITE)
	var err = FileAccess.get_open_error()
	if err != OK:
		print("Error saving file:", err)
		return
	file.store_string(content)
	file.close()
