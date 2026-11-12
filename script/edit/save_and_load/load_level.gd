extends Node

class_name LoadLevel

@export var level_data_node: LevelManager
## 观看视图重演关卡时不要把自己的角色进度上报成目标的关卡。
@export var report_progress: bool = true

var file_name: String = "user://mfmp_"
var date_time: String = "datetime"
var author: String = "author"

func _ready() -> void:
	if GameMode.is_adventure():
		file_name = Adventure.current_level_path()
		return
	if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.HISTORY_EDIT \
	or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.HISTORY_PLAY:
		# 在历史模式下，文件路径由LevelPathSetGetter设置
		return
	if MPManager:
		if GameModeSingleton.game_mode != GameModeSingleton.GameModeType.PLAY:
			date_time = MPManager.game_start_time
			var unique_id: String = OS.get_unique_id()
			unique_id = unique_id.replace("{", "")
			unique_id = unique_id.substr(0, 5)
			author = MPManager.player_name.validate_filename() + "_" + unique_id
		else:
			var levels: Array[String] = MPManager.random_levels
			if levels.is_empty():
				Log.e("load_level.gd", "多人关卡列表为空，无法加载本关")
				return
			var index: int = clampi(MPManager.current_level_count, 0, levels.size() - 1)
			# 缺关本地跳过：不全局删关，也不影响其他玩家。
			while index < levels.size() and not FileAccess.file_exists(levels[index]):
				Log.w("load_level.gd", "缺少关卡，跳过：%s" % levels[index])
				index += 1
			if index >= levels.size():
				Log.w("load_level.gd", "没有可用关卡，进入观看/结果")
				MPManager.current_level_count = levels.size()
				MPManager.flow.notify_reach_end()
				var target: String = MatchFlowService.SCENE_SPECTATE \
					if MPManager.phase == RoomPhase.Phase.PLAY \
					else MatchFlowService.SCENE_RESULT
				GlobalTransition.change_scene_to_file.call_deferred(target)
				return
			MPManager.current_level_count = index
			if report_progress:
				MPManager.flow.report_current_level(index)
			file_name = levels[index]
			return
	file_name += date_time + "_" + author + ".lvl"

func _on_load_button_pressed() -> void:
	if file_name.is_empty():
		Log.w("load_level", "没有当前关卡路径，跳过加载")
		return
	var content: String = load_from_level()
	if content == "":
		push_error("Level has no content.")
		return
	level_data_node.load_level_data_from_json(content)
	if GameMode.is_adventure():
		Adventure.on_level_loaded(file_name)

func load_from_level() -> String:
	var file: FileAccess = FileAccess.open(file_name, FileAccess.READ)
	if not file:
		print("[load_level.gd] Failed to open file or this is a new file.")
		var err: Error = FileAccess.get_open_error()
		if err != OK:
			Log.e("load_level.gd", ["Error loading file:", err, "path:", file_name, "mode:", GameModeSingleton.game_mode])
			return ""
	var content: String = file.get_as_text()
	file.close()
	return content

func _on_debug_load(path: String) -> void:
	file_name = path
	var content: String = load_from_level()
	if content == "":
		push_error("Level has no content.")
		return
	level_data_node.load_level_data_from_json(content)