extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 记录过关转场期间每帧 delta，找卡顿峰值。
##   Godot --path . res://tools/adventure_preload_perf_probe.tscn

const RESULT_PATH: String = "res://tools/adventure_preload_perf_probe_result.txt"
const TEMP_STORE: String = "user://adventure_perf_probe.ini"
const RECORD_SECONDS: float = 2.2

var _lines: PackedStringArray = PackedStringArray()
var _recording: bool = false
var _elapsed: float = 0.0
var _max_delta: float = 0.0
var _max_at: float = 0.0
var _slow_frames: int = 0
var _frame_count: int = 0


func _process(delta: float) -> void:
	if not _recording:
		return
	_elapsed += delta
	_frame_count += 1
	if delta > _max_delta:
		_max_delta = delta
		_max_at = _elapsed
	if delta > 0.033:
		_slow_frames += 1


func _ready() -> void:
	# 暂停期间也要继续采样（框架节点是 INHERIT）。
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if not started:
		_lines.append("start=false")
		_finish()
		return

	# _ready 期间 root 还在 setup children，等一帧再挂。
	await get_tree().process_frame
	var packed: PackedScene = load(Adventure.PLAY_SCENE) as PackedScene
	var play: Node = packed.instantiate()
	get_tree().root.add_child(play)
	get_tree().current_scene = play

	await get_tree().create_timer(2.5).timeout
	Adventure.on_level_loaded(Adventure.current_level_path())
	Adventure.on_level_passed()
	_recording = true
	Adventure.play_transition("pass", "")

	await get_tree().create_timer(RECORD_SECONDS).timeout
	_recording = false
	_lines.append("max_delta=%.4f at=%.2f" % [_max_delta, _max_at])
	_lines.append("slow_frames=%d total=%d" % [_slow_frames, _frame_count])
	_finish()


func _finish() -> void:
	get_tree().paused = false
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
		file.close()
	if FileAccess.file_exists(TEMP_STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_STORE))
	get_tree().quit()
