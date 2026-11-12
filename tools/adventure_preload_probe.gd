extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 无头探针：验证过关转场「播到一半加载下一关 → 加载完冻结 → 播完解冻」。
##   Godot --headless --path . res://tools/adventure_preload_probe.tscn

const OUTPUT: String = "res://tools/adventure_preload_probe_result.txt"
const TEMP_STORE: String = "user://adventure_preload_probe.ini"
const LEVEL_A: String = "user://adventure_preload_a.lvl"
const LEVEL_B: String = "user://adventure_preload_b.lvl"

var _lines: PackedStringArray = PackedStringArray()
var _transition: CanvasLayer = null
var _play: Node = null
var _container_rect: Rect2 = Rect2()


func _ready() -> void:
	_write_level(LEVEL_A)
	_write_level(LEVEL_B)

	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	Adventure.store = store
	Adventure.current_run = {
		"active": true,
		"id": "probe",
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

	await get_tree().create_timer(1.0).timeout
	_lines.append("first_key=%s" % Adventure.current_key)
	_transition = Adventure._clear_transition
	_lines.append("transition_found=%s" % str(_transition != null))
	var container: Control = _play.get_node_or_null("GameRoomSize/SubViewportContainer") as Control
	if container != null:
		_container_rect = container.get_global_rect()
	_lines.append("view_rect=%s" % str(_container_rect))

	Adventure.on_level_loaded(Adventure.current_level_path())
	Adventure.on_level_passed()
	Adventure.play_transition("pass", "")

	# 半程 0.83s 后搬运转场、切场景、加载下一关。
	await get_tree().create_timer(1.05).timeout
	_check_midway()

	# 转场总时长 1.66s，留出余量。
	await get_tree().create_timer(1.6).timeout
	_check_end()
	_finish()


func _check_midway() -> void:
	_lines.append("mid_transition_valid=%s" % str(is_instance_valid(_transition)))
	var scene: Node = get_tree().current_scene
	if is_instance_valid(_transition):
		_lines.append("mid_detached=%s" % str(_transition.get_parent() == get_tree().root))
		var root: Control = _transition.get("_detached_root") as Control
		if root != null:
			_lines.append("mid_root_parent=%s" % str(root.get_parent()))
			var container: Control = null
			if scene != null:
				container = scene.get_node_or_null(
					"GameRoomSize/SubViewportContainer"
				) as Control
			_lines.append(
				"mid_root_in_view=%s" % str(container != null and root.get_parent() == container)
			)
			if container != null:
				var viewport_index: int = -1
				var border_index: int = -1
				var root_index: int = root.get_index()
				for index: int in range(container.get_child_count()):
					var child: Node = container.get_child(index)
					if child is SubViewport:
						viewport_index = index
					elif child is Node2D:
						border_index = index
				var order_ok: bool = root_index > viewport_index \
					and (border_index < 0 or root_index < border_index)
				_lines.append("mid_layer_order=%s" % str(order_ok))
			var rect: Rect2 = root.get_global_rect()
			_lines.append("mid_rect=%s" % str(rect))
			var match_rect: bool = absf(rect.position.x - _container_rect.position.x) < 1.0 \
				and absf(rect.position.y - _container_rect.position.y) < 1.0 \
				and absf(rect.size.x - _container_rect.size.x) < 1.0 \
				and absf(rect.size.y - _container_rect.size.y) < 1.0
			_lines.append("mid_rect_match=%s" % str(match_rect))
	_lines.append("mid_paused=%s" % str(get_tree().paused))
	_lines.append("mid_scene_changed=%s" % str(scene != _play))


func _check_end() -> void:
	_lines.append("end_paused=%s" % str(get_tree().paused))
	_lines.append("end_old_scene_freed=%s" % str(not is_instance_valid(_play)))
	var scene: Node = get_tree().current_scene
	_lines.append("end_scene_valid=%s" % str(scene != null and scene != _play))
	if scene != null:
		var manager: LevelManager = scene.find_child("LevelManager", true, false) as LevelManager
		_lines.append(
			"end_level_loaded=%s" % str(manager != null and not manager.level_data_dict.is_empty())
		)
	_lines.append("end_key=%s" % Adventure.current_key)


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
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
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
		"adventure_preload_probe.ini",
		"adventure_preload_probe.ini.tmp",
		"adventure_preload_a.lvl",
		"adventure_preload_b.lvl",
	]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
