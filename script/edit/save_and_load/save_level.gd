extends Node

@export var level_data_node: LevelManager
@export var emulate_bad_level: bool

var file_name: String = "user://mfmp_"
var date_time: String = "datetime"
var author: String = "author"

var multiplayer_manager: MultiplayerManager


func _ready() -> void:
	multiplayer_manager = MPManager
	date_time = multiplayer_manager.game_start_time
	var unique_id: String = OS.get_unique_id()
	unique_id = unique_id.replace("{", "")
	unique_id = unique_id.substr(0, 5)
	author = multiplayer_manager.player_name.validate_filename() + "_" + unique_id
	file_name += date_time + "_" + author + ".lvl"
	MPManager.save_level_requested.connect(_on_save_button_pressed)


func _on_save_button_pressed() -> void:
	if level_data_node == null:
		return
	var level_data_json: String = level_data_node.get_level_data_json()
	Log.i("save_level.gd", ["save path: ", file_name])
	save_to_level(level_data_json)
	Log.i("save_level.gd", "Level saved.")
	# 不再把整段关卡 JSON 留在玩家资料里，传输服务直接从磁盘读。
	multiplayer_manager.player.level_file_name = file_name
	if emulate_bad_level and Input.is_key_pressed(KEY_Q):
		multiplayer_manager.player.level_file_name = ""


func save_to_level(content: String) -> void:
	if content.is_empty():
		Log.e("Cannot save empty level data")
		return
	var tmp_file_name: String = file_name + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_file_name, FileAccess.WRITE)
	var err: Error = FileAccess.get_open_error()
	if err != OK or not file:
		Log.i("save_level.gd", "Error saving file: %d" % [err])
		return
	file.store_string(content)
	file.close()
	var dir: DirAccess = DirAccess.open("user://")
	if dir:
		var rename_err: Error = dir.rename(tmp_file_name, file_name)
		if rename_err != OK:
			Log.e("Failed to rename temp file: %d" % [rename_err])
	else:
		Log.e("Failed to open user directory")
