extends Node

@export var level_data_node: LevelManager

var file_name: String = "user://mfp_kd_"
var date_time: String = "datetime"
var author: String = "author"

func _ready() -> void:
	file_name += date_time + "_" + author + ".lvl"
	print("User data path: ", OS.get_user_data_dir())

func _on_load_button_pressed() -> void:
	var content = load_from_level()
	if content == "":
		return
	level_data_node.load_level_data_from_json(content)

func load_from_level() -> String:
	var file = FileAccess.open(file_name, FileAccess.READ)
	if not file:
		print("Failed to open file or this is a new file.")
		return ""
	var content = file.get_as_text()
	file.close()
	return content
