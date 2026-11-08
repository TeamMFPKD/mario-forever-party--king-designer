extends VBoxContainer

## 关卡传输界面进度显示：第一行原提示文案，第二行「接收关卡数 / 总关卡数」「准备人数 / 总人数」。

const LEVEL_COUNT_FORMAT: String = "接收关卡（%d/%d）"
const READY_COUNT_FORMAT: String = "准备人数（%d/%d）"
const INVALID_LEVEL_DATA: String = "invalid"

@onready var _level_count_label: Label = $ProgressRow/LevelCountLabel
@onready var _ready_count_label: Label = $ProgressRow/ReadyCountLabel

var _multiplayer_manager: MultiplayerManager


func _ready() -> void:
	_multiplayer_manager = MPManager
	# 格式化后的文本由本脚本翻译，关闭自动翻译避免重复处理
	_level_count_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ready_count_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_update_progress()


func _process(_delta: float) -> void:
	_update_progress()


func _update_progress() -> void:
	if not is_instance_valid(_multiplayer_manager):
		return
	var total_count: int = _multiplayer_manager.players.size()
	var received_level_count: int = 0
	var ready_count: int = 0
	for p: Dictionary in _multiplayer_manager.players:
		var level_data: String = str(p.get("level_data", INVALID_LEVEL_DATA))
		if level_data != INVALID_LEVEL_DATA and not level_data.is_empty():
			received_level_count += 1
		if p.get("ready", false) == true:
			ready_count += 1
	_update_label(_level_count_label, LEVEL_COUNT_FORMAT, received_level_count, total_count)
	_update_label(_ready_count_label, READY_COUNT_FORMAT, ready_count, total_count)


func _update_label(target_label: Label, format_key: String, count: int, total_count: int) -> void:
	var label_text: String = tr(format_key) % [count, total_count]
	if target_label.text == label_text:
		return
	target_label.text = label_text
