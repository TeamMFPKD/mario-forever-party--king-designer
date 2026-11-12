extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 窗口截图：检查转场搬到关卡视口后，黄色块有没有漏到 HUD / 边框外面。
##   Godot --path . res://tools/adventure_preload_shot.tscn
## 输出：adventure_preload_shot_mid.png / _slide.png / _end.png

const OUT_EARLY: String = "res://tools/adventure_preload_shot_early.png"
const OUT_MID: String = "res://tools/adventure_preload_shot_mid.png"
const OUT_SLIDE: String = "res://tools/adventure_preload_shot_slide.png"
const OUT_END: String = "res://tools/adventure_preload_shot_end.png"
const RESULT_PATH: String = "res://tools/adventure_preload_shot_result.txt"
const TEMP_STORE: String = "user://adventure_preload_shot.ini"
const LEVEL_A: String = "user://adventure_preload_shot_a.lvl"
const LEVEL_B: String = "user://adventure_preload_shot_b.lvl"

var _lines: PackedStringArray = PackedStringArray()
var _play: Node = null


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_write_level(LEVEL_A)
	_write_level(LEVEL_B)

	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	Adventure.store = store
	Adventure.current_run = {
		"active": true,
		"id": "shot",
		"mode": "finite",
		"seed": 1,
		"tier": 0,
		"active_tier": 0,
		"started_at": 0,
		"index": 0,
		"total_levels": 2,
		"lives_total": 4,
		"lives_left": 4,
		"lives_cap": 100,
		"cleared_count": 0,
		"skipped_count": 0,
		"skipped_soft": 0,
		"skipped_hard": 0,
		"cycle": 1,
		"cycle_played": [],
		"level_keys": [LEVEL_A.get_file(), LEVEL_B.get_file()],
		"level_fingerprints": ["", ""],
	}
	GameModeSingleton.set("game_mode", GameMode.GameModeType.ADVENTURE)

	var packed: PackedScene = load(Adventure.PLAY_SCENE) as PackedScene
	if packed == null:
		_lines.append("PLAY_SCENE LOAD_FAIL")
		_finish()
		return
	_play = packed.instantiate()
	get_tree().root.add_child(_play)
	get_tree().current_scene = _play

	await get_tree().create_timer(1.0).timeout
	Adventure.on_level_loaded(Adventure.current_level_path())
	Adventure.on_level_passed()
	Adventure.play_transition("pass", "")

	# 划入阶段：黄色块从右侧进入，必须被关卡视口裁掉，不能盖到右侧信息面板。
	await get_tree().create_timer(0.12).timeout
	await _save(OUT_EARLY)

	# 半程 0.83s + 搬运转场/切场景/加载，再留一点余量：此时黄色块应该全屏但只盖关卡视口。
	await get_tree().create_timer(0.83).timeout
	await _save(OUT_MID)
	_lines.append("mid_paused=%s" % str(get_tree().paused))

	# 划出阶段：黄色块向左移出，漏出的应该是冻结的新关卡。
	await get_tree().create_timer(0.55).timeout
	await _save(OUT_SLIDE)
	_lines.append("slide_paused=%s" % str(get_tree().paused))

	# 转场结束：解冻开始游戏。
	await get_tree().create_timer(1.2).timeout
	await _save(OUT_END)
	_lines.append("end_paused=%s" % str(get_tree().paused))
	_finish()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		_lines.append("%s=FAIL" % path)
		return
	var error: Error = image.save_png(path)
	_lines.append("%s=%s" % [path.get_file(), error_string(error)])


func _write_level(path: String) -> void:
	var data: Dictionary = {
		"version": 2,
		"time_used": -1,
		"level_theme": 5,
		"level_size": [0, 0, 640, 480],
		"tilemap_data": [],
		"object_data": [],
		"pipe_line_data": [],
		"pass_count": 0,
		"death_count": 0,
		"lives": 2,
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, ""))
	file.close()


func _finish() -> void:
	get_tree().paused = false
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
		file.close()
	_cleanup()
	get_tree().quit()


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in [
		"adventure_preload_shot.ini",
		"adventure_preload_shot.ini.tmp",
		"adventure_preload_shot_a.lvl",
		"adventure_preload_shot_b.lvl",
	]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
