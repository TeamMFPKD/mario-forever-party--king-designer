extends UiSoundButton

## 记录来源房间的场景路径，退出关卡/编辑器时按它返回（从"喜欢的关卡"进入就回收藏页）。
const RETURN_SCENE_META: String = "return_scene_path"

@export var target_game_mode: GameModeSingleton.GameModeType
@export var level_file_name_label: Label

@export var is_liked_course: bool = false

var basic_path_name: String = "user://"
var level_path_name: String
var level_path_set: Node

## 卡片所在房间（按钮按下时的 current_scene 可能已被场景切换清空，故在 ready 时记下）
var _return_scene_path: String = ""

func _ready() -> void:
	super()
	pressed.connect(_on_button_pressed)
	if is_liked_course:
		level_path_name = LikedCourses.level_path(level_file_name_label.text)
	else:
		level_path_name = basic_path_name + level_file_name_label.text
	level_path_set = get_tree().get_first_node_in_group("level_path_set")
	var room: Node = get_tree().current_scene
	if is_instance_valid(room):
		_return_scene_path = room.scene_file_path

func _on_button_pressed() -> void:
	if not level_path_set:
		push_error("Level path set node not found")
		return
	level_path_set.set_meta("level_path_name", level_path_name)
	_record_return_scene()
	GameModeSingleton.game_mode = target_game_mode

func _record_return_scene() -> void:
	if _return_scene_path.is_empty():
		level_path_set.remove_meta(RETURN_SCENE_META)
		return
	level_path_set.set_meta(RETURN_SCENE_META, _return_scene_path)
