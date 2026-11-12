extends Node

class_name LevelManager

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

signal level_theme_changed(level_theme: LevelThemeEnum)

signal load_level

## 关卡数据（瓦片/对象/管道）全部写进场景之后发出，供依赖地图内容的对象重建。
signal level_data_loaded

signal lives_changed

@export_category("Level Data")
@export var version: int = 2
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
	GALAXY,
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
@export var tile_map: TileMapLayer
@export var tile_set_manager: TileSetManager
@export var object_map: ObjectMapLayer
@export var clear_pipe_draw: Node
@export var pipe_builder: Node
@export var bgp_manager: BgpManager

@export var lives: int = 2:
	set(value):
		value = clamp(value, 1, 3)
		lives = value
		emit_signal("lives_changed")

var level_data_dict: Dictionary
var _cached_pipe_line_data: Array = []

## 后台线程预解析好的关卡数据（百人团换关用）：LoadLevel 优先拿它，省掉同步读文件 + JSON 解析。
var preloaded_level_data: Dictionary = {}
## 关卡数据是否已经完整写进场景（分帧加载结束、level_data_loaded 发出前置 true）。
var is_level_data_ready: bool = false

func _ready() -> void:
	#if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.PLAY \
	#or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.EDIT:
	var timer_singleton: Timer = get_tree().get_first_node_in_group("timer_singleton")
	time_used = int(timer_singleton.wait_time)
	emit_signal("load_level")
	update_theme()

func get_level_data_json() -> String:
	level_size = [level_camera.limit_top, level_camera.limit_left, level_camera.limit_right, level_camera.limit_bottom]

	tile_data = tile_map.tile_map_data

	# 使用ObjectMapLayer的get_object_data方法获取正确的保存格式
	var object_data: Array = []
	if object_map and object_map.has_method("get_object_data"):
		object_data = object_map.get_object_data()
	else:
		push_warning("ObjectMapLayer not found or missing get_object_data method")

	# 获取clear pipe线数据
	var pipe_line_data: Array = []
	if clear_pipe_draw and clear_pipe_draw.has_method("get_pipe_line_data"):
		pipe_line_data = clear_pipe_draw.call("get_pipe_line_data")
		_cached_pipe_line_data = pipe_line_data.duplicate(true)
	else:
		pipe_line_data = _cached_pipe_line_data

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
	
	var level_data_json: String = JSON.stringify(level_data_dict, "")
	return level_data_json

func load_level_data_from_json(level_data_json: String) -> void:
	var json: JSON = JSON.new()
	var error: Error = json.parse(level_data_json)

	if error != OK:
		push_error("Failed to parse level data JSON.")
		return
	var data_raw: Variant = json.data
	if not (data_raw is Dictionary):
		push_error("Level data is not a dictionary.")
		return
	apply_level_data(data_raw as Dictionary)


## 把已经解析好的关卡字典写进场景。
## 对象实例化按帧分批（见 ObjectMapLayer.load_object_data），避免大关卡一次性卡住主线程。
func apply_level_data(data: Dictionary) -> void:
	# 加载过程中会重建全部数据源，旧历史全部失效：先停止记录，加载完清空。
	var stack: CommandStack = CommandStack.find_in(get_tree())
	if stack != null:
		stack.set_recording_enabled(false)

	is_level_data_ready = false
	level_data_dict = data

	var version_value: int = type_convert(level_data_dict.get("version", 1), TYPE_INT)
	version = version_value
	time_used = level_data_dict.get("time_used", -1)

	level_size = level_data_dict.get("level_size", [0, 0, 640, 480])
	var level_size_top: int = level_size[0]
	var level_size_left: int = level_size[1]
	var level_size_right: int = level_size[2]
	var level_size_bottom: int = level_size[3]
	# 一次性应用四个边界：逐个 set_limit_* 会发 4 次 limit_changed，
	# 每次都让 BackgroundSet 重建背景，切关时明显卡顿。
	level_camera.apply_limits(
		level_size_top, level_size_left, level_size_right, level_size_bottom
	)

	level_theme = level_data_dict.get("level_theme", LevelThemeEnum.OVERWORLD)

	pass_count = level_data_dict.get("pass_count", 0)
	death_count = level_data_dict.get("death_count", 0)

	lives = level_data_dict.get("lives", 2)
	if not GameMode.is_adventure():
		var lives_set_when_ready: bool = LifeManager.get("is_lives_set_when_ready")
		if not lives_set_when_ready:
			LifeManager.set("lives", lives)
			LifeManager.set("is_lives_set_when_ready", true)
	
	# 加载瓦片数据
	var tile_data_array: Array = level_data_dict.get("tilemap_data", [])
	if tile_data_array is Array and tile_data_array != []:
		var tile_data_bytes_array: PackedByteArray = PackedByteArray(tile_data_array)
		tile_map.tile_map_data = tile_data_bytes_array
		Log.i("LevelManager", "瓦片数据加载完成")
	else:
		push_warning("No tile data found in level file")
	
	# 加载对象数据
	var object_data_array: Array = level_data_dict.get("object_data", [])
	if object_data_array is Array:
		if object_map and object_map.has_method("load_object_data"):
			object_map.load_object_data(object_data_array)
			Log.i("LevelManager", ["对象数据加载完成，共加载 ", object_data_array.size(), " 个对象"])
		else:
			push_warning("ObjectMapLayer not found or missing load_object_data method")
	else:
		push_warning("No object data found in level file")

	# 加载clear pipe线数据
	var pipe_line_data_array: Array = level_data_dict.get("pipe_line_data", [])
	if pipe_line_data_array is Array and pipe_line_data_array.size() > 0:
		_cached_pipe_line_data = pipe_line_data_array.duplicate(true)
	if pipe_line_data_array is Array and pipe_line_data_array.size() > 0:
		_cached_pipe_line_data = pipe_line_data_array.duplicate(true)
	if pipe_line_data_array is Array and pipe_line_data_array.size() > 0:
		if clear_pipe_draw and clear_pipe_draw.has_method("load_from_pipe_line_data"):
			clear_pipe_draw.call("load_from_pipe_line_data", pipe_line_data_array)
			Log.i("LevelManager", ["管道线数据加载完成，共加载 ", pipe_line_data_array.size(), " 条管道"])
		elif pipe_builder and pipe_builder.has_method("build_pipes_from_lines"):
			var line_data_list: Array = []
			for line_entry: Dictionary in pipe_line_data_array:
				var pts_data: Array = line_entry.get("points", [])
				var points: Array[Vector2] = []
				for p_dict: Dictionary in pts_data:
					var point_x: float = p_dict.get("x", 0)
					var point_y: float = p_dict.get("y", 0)
					points.append(Vector2(point_x, point_y))
				if points.size() >= 2:
					line_data_list.append({"points": points})
			if line_data_list.size() > 0:
				pipe_builder.call("build_pipes_from_lines", line_data_list)
				Log.i("LevelManager", ["管道线数据加载完成，共加载 ", line_data_list.size(), " 条管道"])
	else:
		if clear_pipe_draw and clear_pipe_draw.has_method("clear_all_lines"):
			clear_pipe_draw.call("clear_all_lines")
		if pipe_builder and pipe_builder.has_method("clear_all_pipes"):
			pipe_builder.call("clear_all_pipes")

	Log.i("LevelManager", "Level loaded.")

	if stack != null:
		stack.clear()
		stack.set_recording_enabled(true)

	is_level_data_ready = true
	level_data_loaded.emit()

	
	
func update_theme() -> void:
	# 主题切换本身是可撤销命令（CmdChangeLevelTheme），这里不能清空历史，
	# 否则命令刚压栈就被清掉、重做栈也一起丢失。
	# 换主题虽然会替换 TileSet，但撤销顺序保证“先撤新主题的瓦片操作、
	# 再回到旧主题”，瓦片快照始终与当时的 TileSet 对应。
	# 关卡加载会重建全部数据源，已由 load_level_data_from_json() 显式 clear()。

	# Update TileMap and Background
	if tile_set_manager != null:
		tile_set_manager.update_tile_set(level_theme)
	else:
		print("TileSetManager is null!")
	if bgp_manager != null:
		bgp_manager.update_bgp(level_theme)
	else:
		print("BgpManager is null!")
