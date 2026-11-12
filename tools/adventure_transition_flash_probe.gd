extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 逐帧采样过关转场期间的画面颜色，定位「突然闪一下」。
##   Godot --path . res://tools/adventure_transition_flash_probe.tscn

const RESULT_PATH: String = "res://tools/adventure_transition_flash_probe_result.txt"
const TEMP_STORE: String = "user://adventure_flash_probe.ini"

## 逻辑 1920×1080 下的采样点：主视口背景 / 边框 / 左侧面板 / 关卡画面。
const POINTS: Dictionary = {
	"bg": Vector2(14.0, 540.0),
	"border": Vector2(960.0, 14.0),
	"panel": Vector2(180.0, 720.0),
	"level": Vector2(960.0, 520.0),
}

var _lines: PackedStringArray = PackedStringArray()
var _play: Node = null
var _transition: CanvasLayer = null


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
	if not started:
		_lines.append("start=false")
		_finish()
		return

	# _ready 期间 root 还在 setup children，直接 add_child 会被拒绝，等一帧再挂。
	await get_tree().process_frame
	var packed: PackedScene = load(Adventure.PLAY_SCENE) as PackedScene
	_play = packed.instantiate()
	get_tree().root.add_child(_play)
	get_tree().current_scene = _play

	await get_tree().create_timer(2.5).timeout
	_lines.append("play_in_tree=%s children=%d" % [
		str(_play.is_inside_tree()), _play.get_child_count()
	])
	var clear_node: CanvasLayer = Adventure._clear_transition
	_lines.append("clear_valid=%s" % str(is_instance_valid(clear_node)))
	if is_instance_valid(clear_node):
		_lines.append("clear_path=%s" % str(clear_node.get_path()))
	else:
		var found: Node = _play.get_node_or_null(
			"GameRoomSize/SubViewportContainer/SubViewport/AdventureClearTransition"
		)
		_lines.append("found_in_scene=%s" % str(found != null))
	Adventure.on_level_loaded(Adventure.current_level_path())
	Adventure.on_level_passed()
	_transition = Adventure._clear_transition
	Adventure.play_transition("pass", "")
	var previous_id: int = _play.get_instance_id() if is_instance_valid(_play) else 0
	_lines.append("first_scene_id=%d" % previous_id)

	# 切换发生在半程 0.83s 附近，提前一点开始逐帧采样。
	await get_tree().create_timer(0.70).timeout
	var index: int = 0
	while index < 26:
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var scene: Node = get_tree().current_scene
		var scene_id: int = scene.get_instance_id() if scene != null else 0
		if image == null:
			_lines.append("frame_%02d=NO_IMAGE scene=%d paused=%s" % [
				index, scene_id, str(get_tree().paused)
			])
		else:
			if index == 0:
				image.save_png("res://tools/adventure_flash_frame00.png")
			if index >= 7 and index <= 10:
				image.save_png("res://tools/adventure_flash_frame%02d.png" % index)
			_lines.append("frame_%02d size=%s %s scene=%d old=%s paused=%s" % [
				index, str(image.get_size()), _sample(image), scene_id,
				str(scene_id == previous_id), str(get_tree().paused)
			])
			if index >= 8 and index <= 10:
				_lines.append("  %s" % _transition_state())
		index += 1
	_finish()


func _transition_state() -> String:
	if not is_instance_valid(_transition):
		return "transition=null"
	var root: Control = _transition.get("_detached_root") as Control
	if root == null or not is_instance_valid(root):
		return "root=null"
	var parent_name: String = "null"
	if root.get_parent() != null:
		parent_name = str(root.get_parent().name)
	return "root_rect=%s visible=%s parent=%s" % [
		str(root.get_global_rect()), str(root.visible), parent_name
	]


func _sample(image: Image) -> String:
	var image_size: Vector2 = Vector2(float(image.get_width()), float(image.get_height()))
	var scale: Vector2 = image_size / Vector2(1920.0, 1080.0)
	var parts: PackedStringArray = PackedStringArray()
	for key: String in POINTS.keys():
		var point: Vector2 = POINTS[key]
		var px: int = clampi(int(point.x * scale.x), 0, image.get_width() - 1)
		var py: int = clampi(int(point.y * scale.y), 0, image.get_height() - 1)
		var color: Color = image.get_pixel(px, py)
		parts.append("%s=%s" % [key, color.to_html(false)])
	return " ".join(parts)


func _finish() -> void:
	get_tree().paused = false
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
		file.close()
	if FileAccess.file_exists(TEMP_STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_STORE))
	get_tree().quit()
