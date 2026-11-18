extends Control

## 百人团的快速导入页：一个输入框 + 导入 / 取消。
##
## 打开时优先把剪贴板内容读进来（玩家刚复制的码不必再右键粘贴一次），
## 但只有「看着像一条码」才自动填——否则会把玩家别处的剪贴板内容塞进框里。
##
## 结果提示不在本页做：导入成功 / 失败一律交给全局 Notice（与导出、删档一致），
## 本页只负责收文本、发出 submitted 让舞台去调 Adventure.import_share_code()。

signal submitted(text: String)
signal cancelled

## 输入框最多接受的字符数：一条码约 2~4 万字符，给足余量但不无限。
const MAX_CODE_LENGTH: int = 200000

@onready var _input: LineEdit = $Panel/Margin/VBox/CodeInput
@onready var _hint: Label = $Panel/Margin/VBox/Hint
@onready var _import_button: Button = $Panel/Margin/VBox/Buttons/ImportButton
@onready var _cancel_button: Button = $Panel/Margin/VBox/Buttons/CancelButton


func _ready() -> void:
	_input.max_length = MAX_CODE_LENGTH
	_import_button.pressed.connect(_on_import_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_input.text_submitted.connect(_on_text_submitted)
	_input.text_changed.connect(_refresh_hint)


## 每次打开都重置：清空上一次的输入，再把剪贴板里的码自动填进来。
func open() -> void:
	_input.text = ""
	var clip: String = _clipboard_text()
	if AdventureShareCode.looks_like_code(clip):
		_input.text = clip
	visible = true
	_refresh_hint()
	_focus_input.call_deferred()


func close() -> void:
	visible = false


func _focus_input() -> void:
	if not is_inside_tree():
		return
	_input.grab_focus()
	# 光标落到末尾：玩家若想手工替换，直接全选更顺手。
	_input.caret_column = _input.text.length()


## 剪贴板在无头 / Web 环境下可能拿不到，当作「没有」处理，不报错。
func _clipboard_text() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	return DisplayServer.clipboard_get()


## text_changed 会把新文本一起传进来；这里不依赖那个参数，直接从输入框读当前值。
func _refresh_hint(_new_text: String = "") -> void:
	var has_text: bool = not _input.text.strip_edges().is_empty()
	_import_button.disabled = not has_text
	if not has_text:
		_hint.text = tr("把存档码粘贴到这里")
		return
	if not AdventureShareCode.looks_like_code(_input.text):
		_hint.text = tr("这段文本不像存档码，确认后再导入")
		return
	_hint.text = tr("看起来是一条存档码，点「导入」")


func _on_text_submitted(_text: String) -> void:
	_on_import_pressed()


func _on_import_pressed() -> void:
	var text: String = _input.text.strip_edges()
	if text.is_empty():
		return
	submitted.emit(text)


func _on_cancel_pressed() -> void:
	cancelled.emit()
