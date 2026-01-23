extends Node

class_name LevelManager

signal level_theme_changed(level_theme: LevelThemeEnum)

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
		emit_signal("level_theme_changed", level_theme)
		
@export var tile_data: PackedByteArray

@export_category("References")
@export var tile_map : TileMapLayer
@export var tile_set_manager : TileSetManager
@export var object_map : ObjectMapLayer
@export var bgp_manager : BgpManager

var level_data_dict: Dictionary

func get_level_data_json() -> String:
	tile_data = tile_map.tile_map_data

	# 使用ObjectMapLayer的get_object_data方法获取正确的保存格式
	var object_data = []
	if object_map and object_map.has_method("get_object_data"):
		object_data = object_map.get_object_data()
	else:
		push_warning("ObjectMapLayer not found or missing get_object_data method")

	level_data_dict = {
		"version": version,
		"level_theme": level_theme,
		"tilemap_data": tile_data as Array,
		"object_data": object_data
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
	
	# 加载瓦片数据
	var tile_data_array = level_data_dict.get("tilemap_data", [])
	if tile_data_array is Array and tile_data_array != []:
		var tile_data_bytes_array = PackedByteArray(tile_data_array)
		tile_map.tile_map_data = tile_data_bytes_array
		print("瓦片数据加载完成")
	else:
		push_warning("No tile data found in level file")
	
	# 加载对象数据
	var object_data_array = level_data_dict.get("object_data", [])
	if object_data_array is Array:
		if object_map and object_map.has_method("load_object_data"):
			object_map.load_object_data(object_data_array)
			print("对象数据加载完成，共加载 ", object_data_array.size(), " 个对象")
		else:
			push_warning("ObjectMapLayer not found or missing load_object_data method")
	else:
		push_warning("No object data found in level file")

	print("Level loaded.")

	
	
func update_theme() -> void:
	# Update TileMap and Background
	tile_set_manager.update_tile_set(level_theme)
	bgp_manager.update_bgp(level_theme)