extends VBoxContainer

## 关卡传输界面进度显示：第一行原提示文案，第二行「接收关卡数 / 总关卡数」「准备人数 / 总人数」。
## 只订阅事件，不再每帧扫玩家列表。

const LEVEL_COUNT_FORMAT: String = "接收关卡（%d/%d）"
const READY_COUNT_FORMAT: String = "准备人数（%d/%d）"

@onready var _level_count_label: Label = $ProgressRow/LevelCountLabel
@onready var _ready_count_label: Label = $ProgressRow/ReadyCountLabel


func _ready() -> void:
	# 格式化后的文本由本脚本翻译，关闭自动翻译避免重复处理
	_level_count_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ready_count_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	MPManager.players_updated.connect(_update_progress)
	MPManager.levels.progress_changed.connect(_update_progress)
	_update_progress()


func _update_progress() -> void:
	var total_count: int = 0
	var received_level_count: int = 0
	var ready_count: int = 0
	for profile: PlayerProfile in MPManager.players:
		if profile.is_spectator:
			continue
		total_count += 1
		if profile.has_level:
			received_level_count += 1
		if profile.level_ok:
			ready_count += 1
	_update_label(_level_count_label, LEVEL_COUNT_FORMAT, received_level_count, total_count)
	_update_label(_ready_count_label, READY_COUNT_FORMAT, ready_count, total_count)


func _update_label(target_label: Label, format_key: String, count: int, total_count: int) -> void:
	var label_text: String = tr(format_key) % [count, total_count]
	if target_label.text == label_text:
		return
	target_label.text = label_text
