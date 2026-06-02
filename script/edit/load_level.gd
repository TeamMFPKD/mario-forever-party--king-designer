extends Node

class_name LoadLevel

@export var level_data_node: LevelManager

var file_name: String = "user://mfmp_"
var date_time: String = "datetime"
var author: String = "author"

func _ready() -> void:
	if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.HISTORY_EDIT \
	or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.HISTORY_PLAY:
		# 在历史模式下，文件路径由LevelPathSetGetter设置
		return
	if MPManager:
		if GameModeSingleton.game_mode != GameModeSingleton.GameModeType.PLAY:
			date_time = MPManager.game_start_time
			var unique_id = OS.get_unique_id()
			unique_id = unique_id.replace("{", "")
			unique_id = unique_id.substr(0, 5)
			author = MPManager.player_name.validate_filename() + "_" + unique_id
		else:
			file_name = MPManager.random_levels[MPManager.current_level_count]
			return
	file_name += date_time + "_" + author + ".lvl"

func _on_load_button_pressed() -> void:
	var content = load_from_level()
	if content == "":
		push_error("Level has no content.")
		return
	level_data_node.load_level_data_from_json(content)

func load_from_level() -> String:
	var file = FileAccess.open(file_name, FileAccess.READ)
	if not file:
		print("[load_level.gd] Failed to open file or this is a new file.")
		var err = FileAccess.get_open_error()
		if err != OK:
			push_error("[%s] [load_level.gd] Error loading file:" % Time.get_time_string_from_system(), err)
			return ""
	var content = file.get_as_text()
	file.close()
	return content

func _on_debug_load(path: String) -> void:
	file_name = path
	var content = load_from_level()
	if content == "":
		push_error("Level has no content.")
		return
	level_data_node.load_level_data_from_json(content)