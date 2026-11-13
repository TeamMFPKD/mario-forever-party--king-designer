class_name AdventureTrashRow
extends HBoxContainer

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 垃圾桶房间的一行：序号 + 关卡文件名 + 右侧「查看」「恢复」。
## 只负责显示与转发点击，真正的恢复 / 跳转由 AdventureTrashRoom 处理。

signal view_requested(level_path: String)
signal restore_requested(key: String)

@export var count_label: Label
@export var name_label: Label
@export var view_button: Button
@export var restore_button: Button

## 恢复用的 ini section key。
var key: String = ""
## 进入 history_edit 用的完整 user:// 路径（支持根目录与 liked courses）。
var level_path: String = ""
## 文件名（含 .lvl），仅用于显示。
var file_name: String = ""


func _ready() -> void:
	view_button.pressed.connect(_on_view_pressed)
	restore_button.pressed.connect(_on_restore_pressed)


func bind(index: int, level: Dictionary) -> void:
	key = str(level.get("key", ""))
	file_name = str(level.get("file", key))
	if not file_name.is_empty() and not file_name.ends_with(".lvl"):
		file_name += ".lvl"
	level_path = str(level.get("level_path", ""))
	if level_path.is_empty():
		level_path = "user://" + file_name

	count_label.text = str(index)
	# 与 history 的行保持一致：直接显示完整文件名（含 .lvl）。
	name_label.text = file_name if not file_name.is_empty() else "（未知关卡）"
	name_label.tooltip_text = file_name

	var exists: bool = bool(level.get("file_exists", false))
	view_button.disabled = not exists
	view_button.tooltip_text = "" if exists else "关卡文件已缺失，无法查看"


func _on_view_pressed() -> void:
	view_requested.emit(level_path)


func _on_restore_pressed() -> void:
	restore_requested.emit(key)
