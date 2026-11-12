extends Control

## history edit / play 左侧的百人团关卡数据卡。
## 读取 LevelPathSet 的 level_path_name，再按文件名查 adventure.ini 的 solo 数据。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

@export var death_value: Label
@export var pass_value: Label
@export var skip_value: Label

const MARGIN_LEFT: float = 24.0
const GAP: float = 16.0
const CAPTURE_STATS_GAP: float = 64.0
const CAPTURE_SIZE: Vector2 = Vector2(200, 150)
const PANEL_SIZE: Vector2 = Vector2(260, 300)

var _level_path: String = ""
var _layout_done: bool = false


func _ready() -> void:
	visible = false
	await get_tree().process_frame
	_layout_left_column()
	_level_path = _current_level_path()
	_refresh()


func _process(_delta: float) -> void:
	if not _layout_done:
		_layout_left_column()
	var path: String = _current_level_path()
	if path != _level_path:
		_level_path = path
		_refresh()


## 左侧列：查看/游玩按钮 → 喜欢截图（如果有）→ 百人团数据。
func _layout_left_column() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var button: Control = _find_top_button(scene)
	var button_left: float = MARGIN_LEFT
	var button_width: float = PANEL_SIZE.x
	var button_bottom: float = 196.0
	if button != null:
		var parent_control: Control = get_parent() as Control
		var parent_rect: Rect2 = parent_control.get_global_rect() if parent_control != null else Rect2()
		var button_rect: Rect2 = button.get_global_rect()
		button_left = button_rect.position.x - parent_rect.position.x
		button_width = button_rect.size.x
		button_bottom = maxf(button_bottom, button_rect.end.y - parent_rect.position.y)

	var slot_top: float = button_bottom + GAP
	var preview: Control = scene.find_child("LikedCoursePreview", true, false) as Control
	var has_capture: bool = false
	if preview != null:
		var capture: TextureRect = preview.get_node_or_null("CaptureTextureRect") as TextureRect
		has_capture = capture != null and capture.texture != null
		preview.visible = has_capture
		if has_capture:
			# 截图比按钮窄，水平居中到按钮下方，避免看起来偏左。
			var capture_x: float = button_left + (button_width - CAPTURE_SIZE.x) * 0.5
			preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			preview.position = Vector2(capture_x, slot_top)
			preview.size = CAPTURE_SIZE
			capture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			capture.offset_left = 0.0
			capture.offset_top = 0.0
			capture.offset_right = 0.0
			capture.offset_bottom = 0.0

	var stats_top: float = slot_top + CAPTURE_SIZE.y + CAPTURE_STATS_GAP
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = button_left
	offset_top = stats_top
	offset_right = button_left + button_width
	offset_bottom = stats_top + PANEL_SIZE.y
	_layout_done = true


func _find_top_button(scene: Node) -> Control:
	for path: String in [
		"GameRoomSize/MarginContainer/Button",
		"GameRoomSize/SaveLoadTest/VBoxContainer/PlayButton",
	]:
		var node: Control = scene.get_node_or_null(path) as Control
		if node != null and node.visible:
			return node
	var button: Control = scene.find_child("Button", true, false) as Control
	if button != null and button.visible:
		return button
	button = scene.find_child("PlayButton", true, false) as Control
	if button != null and button.visible:
		return button
	return null


func _current_level_path() -> String:
	var setter: Node = get_tree().get_first_node_in_group("level_path_set")
	if setter == null:
		return ""
	return str(setter.get_meta("level_path_name", ""))


func _refresh() -> void:
	if Adventure.store == null:
		visible = false
		return
	var key: String = _level_path.get_file()
	if key.is_empty():
		death_value.text = "0"
		pass_value.text = "0"
		skip_value.text = "0"
		visible = false
		return
	var stats: Dictionary = Adventure.store.get_level_data(key)
	var death: int = int(stats.get("solo_death", 0))
	var passed: int = int(stats.get("solo_pass", 0))
	var skipped: int = int(stats.get("solo_skip", 0))
	death_value.text = str(death)
	pass_value.text = str(passed)
	skip_value.text = str(skipped)
	# 三个数全为 0 视为没有百人团数据，整张卡隐藏。
	visible = death != 0 or passed != 0 or skipped != 0
