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

func _on_load_button_pressed() -> void:
	var content = load_from_level()
	if content == "":
		return
	level_data_node.load_level_data_from_json(content)

func load_from_level() -> String:
	var file = FileAccess.open(file_name, FileAccess.READ)
	if not file:
		push_error("Failed to open file or this is a new file.")
		var err = FileAccess.get_open_error()
		if err != OK:
			print("Error loading file:", err)
			return ""
	var content = file.get_as_text()
	file.close()
	return content
