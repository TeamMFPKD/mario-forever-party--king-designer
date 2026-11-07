extends Node

## 全局日志单例（autoload 名：Log）
##
## 统一在日志前加上 [时:分:秒] 时间戳，代替各脚本里手写的
## print("[%s] ..." % Time.get_time_string_from_system())。
##
## 用法：
##   Log.i("LevelSender", "Level data sent.")
##   Log.i("LevelSender", ["原始 JSON 大小：", size / 1024.0, " KB"])
##   Log.i("没有 tag 的消息")
##   Log.w("MPManager", "玩家未就绪")
##   Log.e("save_level.gd", ["保存失败：", err])
##
## 说明：
## - 只传一个参数时，该参数即为消息（不带 tag）。
## - 消息为数组时按顺序拼接（与 print 多参数行为一致），非数组时直接转字符串。

## 日志级别，低于 min_level 的日志不会输出
enum Level {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3,
	SILENT = 4,
}

## 低于该级别的日志不输出
var min_level: Level = Level.DEBUG

## 为 true 时在消息末尾附加调用位置，例如 " (main.gd:42)"
var show_caller: bool = false

func _ready() -> void:
	# 暂停时仍保留日志能力
	process_mode = Node.PROCESS_MODE_ALWAYS

## 调试日志
func d(tag_or_message: Variant, message: Variant = null) -> void:
	if Level.DEBUG < min_level:
		return
	print(_format(tag_or_message, message, _caller()))

## 普通日志
func i(tag_or_message: Variant, message: Variant = null) -> void:
	if Level.INFO < min_level:
		return
	print(_format(tag_or_message, message, _caller()))

## 警告日志
func w(tag_or_message: Variant, message: Variant = null) -> void:
	if Level.WARNING < min_level:
		return
	push_warning(_format(tag_or_message, message, _caller()))

## 错误日志
func e(tag_or_message: Variant, message: Variant = null) -> void:
	if Level.ERROR < min_level:
		return
	push_error(_format(tag_or_message, message, _caller()))

# 拼装 "[时:分:秒] [tag] 消息 (脚本:行号)"
# 只传一个参数时该参数即为消息，传两个参数时前者为 tag、后者为消息
func _format(tag_or_message: Variant, message: Variant, caller: Dictionary) -> String:
	var tag: String = ""
	var body: Variant = tag_or_message
	if message != null:
		tag = str(tag_or_message)
		body = message

	var text: String = "[%s]" % Time.get_time_string_from_system()
	if not tag.is_empty():
		text += " [%s]" % tag

	var content: String = _to_text(body)
	if not content.is_empty():
		text += " " + content

	if not caller.is_empty():
		var source: String = str(caller.get("source", "")).get_file()
		if not source.is_empty():
			text += " (%s:%s)" % [source, str(caller.get("line", 0))]

	return text

# 数组按 print 多参数语义拼接，其余转字符串
func _to_text(message: Variant) -> String:
	if message == null:
		return ""
	if message is Array:
		var parts: Array = message
		var text: String = ""
		for part: Variant in parts:
			text += str(part)
		return text
	return str(message)

# 取调用 Log 方法的脚本位置（show_caller 关闭时不做栈回溯）
func _caller() -> Dictionary:
	if not show_caller:
		return {}
	var frames: Array[Dictionary] = get_stack()
	if frames.size() < 3:
		return {}
	return frames[2]
