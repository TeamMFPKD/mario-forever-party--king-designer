extends Node

@export var tile_map: TileMapLayer

var file_name: String = "user://mfp_kd_"
var date_time: String = "datetime"
var author: String = "author"

func _ready() -> void:
	file_name += date_time + "_" + author + ".lvl"
	print("User data path: ", OS.get_user_data_dir())

func _on_load_button_pressed() -> void:
	var level_data = load_from_level()
	tile_map.tile_map_data = level_data
	print("Level loaded.")

func load_from_level():
	var file = FileAccess.open(file_name, FileAccess.READ)
	var file_length = file.get_length()
	var content = file.get_buffer(file_length)
	return content
