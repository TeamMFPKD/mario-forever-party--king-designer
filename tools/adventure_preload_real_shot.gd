extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 窗口截图：用 user:// 里的真实关卡走一遍过关转场，检查加载期间与切换后的画面。
##   Godot --path . res://tools/adventure_preload_real_shot.tscn

const OUT_BEFORE: String = "res://tools/adventure_preload_real_before.png"
const OUT_EARLY: String = "res://tools/adventure_preload_real_early.png"
const OUT_MID: String = "res://tools/adventure_preload_real_mid.png"
const OUT_SLIDE: String = "res://tools/adventure_preload_real_slide.png"
const OUT_END: String = "res://tools/adventure_preload_real_end.png"
const RESULT_PATH: String = "res://tools/adventure_preload_real_shot_result.txt"
const TEMP_STORE: String = "user://adventure_preload_real.ini"

var _lines: PackedStringArray = PackedStringArray()
var _play: Node = null


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	Adventure.store = store
	var started: bool = Adventure.start_run({
		"pool_source": "all",
		"tier": 0,
		"mode": "finite",
		"run_length": 5,
		"prefer_low_sample": true,
	})
	_lines.append("start=%s" % str(started))
	if not started:
		_finish()
		return
	_lines.append("first=%s" % Adventure.current_level_key())

	# _ready 期间 root 还在 setup children，直接 add_child 会被拒绝，等一帧再挂。
	await get_tree().process_frame
	var packed: PackedScene = load(Adventure.PLAY_SCENE) as PackedScene
	if packed == null:
		_lines.append("PLAY_SCENE LOAD_FAIL")
		_finish()
		return
	_play = packed.instantiate()
	get_tree().root.add_child(_play)
	get_tree().current_scene = _play

	await get_tree().create_timer(2.5).timeout
	await _save(OUT_BEFORE)
	Adventure.on_level_loaded(Adventure.current_level_path())
	Adventure.on_level_passed()
	_lines.append("second=%s" % Adventure.current_level_key())
	Adventure.play_transition("pass", "")

	await get_tree().create_timer(0.12).timeout
	await _save(OUT_EARLY)
	await get_tree().create_timer(0.78).timeout
	await _save(OUT_MID)
	_lines.append("mid_paused=%s" % str(get_tree().paused))
	await get_tree().create_timer(0.65).timeout
	await _save(OUT_SLIDE)
	_lines.append("slide_paused=%s" % str(get_tree().paused))
	await get_tree().create_timer(2.0).timeout
	await _save(OUT_END)
	_lines.append("end_paused=%s" % str(get_tree().paused))
	var scene: Node = get_tree().current_scene
	if scene != null:
		var manager: LevelManager = scene.find_child("LevelManager", true, false) as LevelManager
		_lines.append(
			"end_level_loaded=%s" % str(manager != null and not manager.level_data_dict.is_empty())
		)
	_lines.append("end_key=%s" % Adventure.current_key)
	_finish()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		_lines.append("%s=FAIL" % path)
		return
	var error: Error = image.save_png(path)
	_lines.append("%s=%s" % [path.get_file(), error_string(error)])


func _finish() -> void:
	get_tree().paused = false
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
		file.close()
	if FileAccess.file_exists(TEMP_STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_STORE))
	get_tree().quit()
