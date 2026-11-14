extends Node2D

## 百人团「排除的关卡」房间：列出被永久排除的关卡，允许逐关恢复正常。
##
## 版式参考 room/history.tscn：背景 + 面板 + 标题 + 滚动列表 + 底部返回。
## 数据以 adventure.ini 为准（Adventure.excluded_levels）；恢复只清 excluded 标记，
## 不删关卡文件、不动历史样本，恢复后该关重新参与关卡池与难度分档。

const STAGE_SCENE: String = "res://room/adventure_stage.tscn"
const SELF_SCENE: String = "res://room/adventure_trash.tscn"
const HISTORY_EDIT_SCENE: String = "res://room/history_edit.tscn"
const ROW_SCENE: PackedScene = preload("res://ui/list/adventure_trash_level_info.tscn")
const LEVEL_PATH_SET_GROUP: String = "level_path_set"
const RETURN_SCENE_META: String = "return_scene_path"

@export var level_list: VBoxContainer
@export var scroll: ScrollContainer
@export var title_label: Label
@export var empty_label: Label
@export var back_button: Button

var _first_row_button: Button = null


func _ready() -> void:
	# 专属 BGM 由场景里的 RoomBgm 节点负责：停掉挑战曲、淡入历史房间曲。
	_refresh()


func _refresh() -> void:
	for child: Node in level_list.get_children():
		level_list.remove_child(child)
		child.queue_free()
	_first_row_button = null

	var levels: Array[Dictionary] = Adventure.excluded_levels()
	# 标题固定为「排除的关卡」，不显示文件数；列表行数由下方列表本身呈现。
	title_label.text = "排除的关卡"
	scroll.visible = not levels.is_empty()
	empty_label.visible = levels.is_empty()

	for index: int in range(levels.size()):
		var row: AdventureTrashRow = ROW_SCENE.instantiate() as AdventureTrashRow
		level_list.add_child(row)
		row.bind(index + 1, levels[index])
		row.view_requested.connect(_on_view_requested)
		row.restore_requested.connect(_on_restore_requested)
		if _first_row_button == null:
			_first_row_button = row.restore_button

	_focus_default()


## 只有键盘/手柄主导时才抢焦点；鼠标/触屏模式下 UiFocusPolicy 会把按钮置为不可聚焦。
func _focus_default() -> void:
	if _first_row_button != null and is_instance_valid(_first_row_button) \
			and _first_row_button.focus_mode != Control.FOCUS_NONE:
		_first_row_button.grab_focus()
	elif back_button.focus_mode != Control.FOCUS_NONE:
		back_button.grab_focus()


## 「查看」：把要打开的关卡与「退出编辑器后返回排除的关卡房间」写进 LevelPathSet，再进 history_edit。
func _on_view_requested(level_path: String) -> void:
	if not _bind_history_edit_context(level_path):
		return
	# 「排除的关卡」房间专属 BGM 随场景销毁停止，历史房间自己的 BGM 会接上。
	GlobalTransition.change_scene_to_file(HISTORY_EDIT_SCENE)


## 单独拆出来便于无头探针验证（不会真的切场景）。
func _bind_history_edit_context(level_path: String) -> bool:
	if level_path.is_empty():
		return false
	var path_set: Node = get_tree().get_first_node_in_group(LEVEL_PATH_SET_GROUP)
	if path_set == null:
		Log.w("AdventureTrash", "找不到 LevelPathSet，无法查看关卡")
		return false
	path_set.set_meta("level_path_name", level_path)
	path_set.set_meta(RETURN_SCENE_META, SELF_SCENE)
	GameModeSingleton.game_mode = GameMode.GameModeType.HISTORY_EDIT
	return true


func _on_restore_requested(key: String) -> void:
	if not Adventure.restore_excluded_level(key):
		Log.w("AdventureTrash", ["恢复失败：", key])
		return
	Log.i("AdventureTrash", ["已恢复：", key])
	_refresh()


func _on_back() -> void:
	GlobalTransition.change_scene_to_file(STAGE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
