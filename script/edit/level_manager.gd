extends Node

class_name LevelManager

signal level_theme_changed(level_theme: LevelThemeEnum)

signal load_level

signal lives_changed

@export_category("Level Data")
@export var version: String = "1.0"
@export var time_used: int = -1
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

@export var level_size: Array = [0, 0, 0, 0] # top, left, right, bottom

@export var tile_data: PackedByteArray

@export var pass_count: int = 0
@export var death_count: int = 0

@export_category("References")
@export var level_camera: LevelCamera
@export var tile_map : TileMapLayer
@export var tile_set_manager : TileSetManager
@export var object_map : ObjectMapLayer
@export var clear_pipe_draw : Node
@export var pipe_builder : Node
@export var bgp_manager : BgpManager

@export var lives : int = 2:
	set(value):
		value = clamp(value, 1, 3)
		lives = value
		emit_signal("lives_changed")

var level_data_dict: Dictionary

func _ready() -> void:
	#if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.PLAY \
	#or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.EDIT:
	var timer_singleton = get_tree().get_first_node_in_group("timer_singleton") as Timer
	time_used = int(timer_singleton.wait_time)
	emit_signal("load_level")
	update_theme()

func get_level_data_json() -> String:
	level_size = [level_camera.limit_top, level_camera.limit_left, level_camera.limit_right, level_camera.limit_bottom]

	tile_data = tile_map.tile_map_data

	# 使用ObjectMapLayer的get_object_data方法获取正确的保存格式
	var object_data = []
	if object_map and object_map.has_method("get_object_data"):
		object_data = object_map.get_object_data()
	else:
		push_warning("ObjectMapLayer not found or missing get_object_data method")

	# 获取clear pipe线数据
	var pipe_line_data = []
	if clear_pipe_draw and clear_pipe_draw.has_method("get_pipe_line_data"):
		pipe_line_data = clear_pipe_draw.get_pipe_line_data()

	level_data_dict = {
		"version": version,
		"time_used": time_used,
		"level_theme": level_theme,
		"level_size": level_size,
		"tilemap_data": tile_data as Array,
		"object_data": object_data,
		"pipe_line_data": pipe_line_data,
		"pass_count": pass_count,
		"death_count": death_count,
		"lives": lives,
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
	time_used = level_data_dict.get("time_used", -1)

	level_size = level_data_dict.get("level_size", [0, 0, 640, 480])
	level_camera.set_limit_top(level_size[0])
	level_camera.set_limit_left(level_size[1])
	level_camera.set_limit_right(level_size[2])
	level_camera.set_limit_bottom(level_size[3])

	level_theme = level_data_dict.get("level_theme", LevelThemeEnum.OVERWORLD)

	pass_count = level_data_dict.get("pass_count", 0)
	death_count = level_data_dict.get("death_count", 0)

	lives = level_data_dict.get("lives", 2)
	if not LifeManager.is_lives_set_when_ready:
		LifeManager.lives = lives
		LifeManager.is_lives_set_when_ready = true
	
	# 加载瓦片数据
	var tile_data_array = level_data_dict.get("tilemap_data", [])
	if tile_data_array is Array and tile_data_array != []:
		var tile_data_bytes_array = PackedByteArray(tile_data_array)
		tile_map.tile_map_data = tile_data_bytes_array
		print("[%s] 瓦片数据加载完成" % Time.get_time_string_from_system())
	else:
		push_warning("No tile data found in level file")
	
	# 加载对象数据
	var object_data_array = level_data_dict.get("object_data", [])
	if object_data_array is Array:
		if object_map and object_map.has_method("load_object_data"):
			object_map.load_object_data(object_data_array)
			print("[%s] 对象数据加载完成，共加载 " % Time.get_time_string_from_system(), object_data_array.size(), " 个对象")
		else:
			push_warning("ObjectMapLayer not found or missing load_object_data method")
	else:
		push_warning("No object data found in level file")

	# 加载clear pipe线数据
	var pipe_line_data_array = level_data_dict.get("pipe_line_data", [])
	if pipe_line_data_array is Array and pipe_line_data_array.size() > 0:
		if clear_pipe_draw and clear_pipe_draw.has_method("load_from_pipe_line_data"):
			clear_pipe_draw.load_from_pipe_line_data(pipe_line_data_array)
			print("[%s] 管道线数据加载完成，共加载 " % Time.get_time_string_from_system(), pipe_line_data_array.size(), " 条管道")
		elif pipe_builder and pipe_builder.has_method("build_pipes_from_lines"):
			var line_data_list: Array = []
			for line_entry in pipe_line_data_array:
				var pts_data = line_entry.get("points", [])
				var points: Array[Vector2] = []
				for p_dict in pts_data:
					points.append(Vector2(p_dict.get("x", 0), p_dict.get("y", 0)))
				if points.size() >= 2:
					line_data_list.append({"points": points})
			if line_data_list.size() > 0:
				pipe_builder.build_pipes_from_lines(line_data_list)
				print("[%s] 管道线数据加载完成，共加载 " % Time.get_time_string_from_system(), line_data_list.size(), " 条管道")
	else:
		if clear_pipe_draw and clear_pipe_draw.has_method("clear_all_lines"):
			clear_pipe_draw.clear_all_lines()
		if pipe_builder and pipe_builder.has_method("clear_all_pipes"):
			pipe_builder.clear_all_pipes()

	print("[%s] Level loaded." % Time.get_time_string_from_system())

	
	
func update_theme() -> void:
	# Update TileMap and Background
	if tile_set_manager != null:
		tile_set_manager.update_tile_set(level_theme)
	else:
		push_warning("TileSetManager is null!")
	if bgp_manager != null:
		bgp_manager.update_bgp(level_theme)
	else:
		push_warning("BgpManager is null!")