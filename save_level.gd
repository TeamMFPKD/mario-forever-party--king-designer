extends Node

@export var tile_map: TileMapLayer

var file_name: String = "user://mfp_kd_"
var date_time: String = "datetime"
var author: String = "author"

func _ready() -> void:
	file_name += date_time + "_" + author + ".lvl"
	print("User data path: ", OS.get_user_data_dir())

func _on_save_button_pressed() -> void:
	var level_data = tile_map.tile_map_data
	save_to_level(level_data)
	print("Level saved.")

func save_to_level(content):
	var file = FileAccess.open(file_name, FileAccess.WRITE)
	file.store_buffer(content)
	file.flush()
	file.close()
