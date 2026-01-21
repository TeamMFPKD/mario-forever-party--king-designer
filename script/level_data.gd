extends Node

class_name LevelData

@export_category("Level Data")
@export var version: String = "1.0"
enum LevelThemeEnum {
	CASTLE,
	CASTLE_B,
	CAVE,
	DUSK,
	NIGHT,
	OVERWORLD,
	SAND,
	SNOW,
	SNOW_B,
	VOLCANO,
}
@export var level_theme: LevelThemeEnum:
	set(value):
		level_theme = value
		update_theme()
@export var tile_data: PackedByteArray

@export_category("References")
@export var tile_map : TileMapLayer

var level_data_dict: Dictionary

func get_level_data_json() -> String:
	tile_data = tile_map.tile_map_data

	level_data_dict = {
		"version": version,
		"level_theme": level_theme,
		"test_map_data": tile_data as Array
	}
	
	var level_data_json = JSON.stringify(level_data_dict, "")
	return level_data_json

func load_level_data_from_json(level_data_json: String) -> void:
	var json = JSON.new()
	var error = json.parse(level_data_json)
	
	if error != OK:
		push_error("Failed to parse level data JSON.")
		return

	level_data_dict = json.data

	version = level_data_dict.get("version", "1.0")

	level_theme = level_data_dict.get("level_theme", LevelThemeEnum.OVERWORLD)
	
	var tile_data_array = level_data_dict.get("test_map_data", [])
	if tile_data_array is Array and tile_data_array != []:
		var tile_data_bytes_array = PackedByteArray(tile_data_array)
		tile_map.tile_map_data = tile_data_bytes_array

	else:
		# 为空
		#tile_map.tile_map_data = PackedByteArray()
		push_warning("No tile data found in level file")

	print("Level loaded.")
	
func update_theme() -> void:
	# Update TileMap and Background
	tile_map.update_tile_set(level_theme)
	