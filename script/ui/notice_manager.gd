extends CanvasLayer

## 全局通知面板（autoload 名：Notice）。
##
## 两种形态：
## - 纯信息通知（默认）：一段信息 + 一个「确认」按钮，面板铺满整个屏幕，
##   显示期间会吃掉所有鼠标点击，点「确认」后关闭。
## - 两按钮确认：一段信息 + 「否」「是」两个按钮，默认答案是「否」。
##
## 用法：
##   Notice.show_notice("游戏已经开始，无法加入该房间。", "游戏进行中")
##   Notice.show_notice("端口 %d 已被占用。", "创建房间失败", "确认", [local_port])
##   Notice.hide_notice()                      # 代码里主动关闭
##   await Notice.closed                        # 等玩家点确认
##
##   Notice.show_confirm("删除当前存档？", "删除存档", "否", "是")
##   var accepted: bool = await Notice.answered  # true = 点了「是」
##
## 说明：
## - [param message] / [param title] / 按钮文案会先经过 tr()，再按 [param args] 格式化，
##   所以调用处传中文原文即可，翻译表里按 msgid 配置。
## - 节点树在 _ready 里由 notice_panel.tscn 实例化，这样 autoload 条目可以指向 .gd，
##   其它脚本调用 Notice.xxx() 时静态类型不会退化成 Node。

signal closed

## 两按钮确认的结果：true = 点了「是」，false = 点了「否」。
signal answered(accepted: bool)

const PANEL_SCENE: PackedScene = preload("res://ui/notice_panel.tscn")

## 画在其它 UI 之上（标题界面最高用的是 z_index 600，这里用独立 CanvasLayer）
const CANVAS_LAYER: int = 128

var _panel: Control
var _title_label: Label
var _message_label: Label
var _ok_button: Button
## 「否 / 是」两按钮行：只在 show_confirm() 时出现。
var _button_row: HBoxContainer
var _no_button: Button
var _yes_button: Button


func _ready() -> void:
	layer = CANVAS_LAYER
	# 暂停时也要能显示/关闭
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = PANEL_SCENE.instantiate() as Control
	add_child(_panel)

	_title_label = _panel.get_node("%TitleLabel") as Label
	_message_label = _panel.get_node("%MessageLabel") as Label
	_ok_button = _panel.get_node("%OkButton") as Button
	_button_row = _panel.get_node("%ButtonRow") as HBoxContainer
	_no_button = _panel.get_node("%NoButton") as Button
	_yes_button = _panel.get_node("%YesButton") as Button
	_ok_button.pressed.connect(hide_notice)
	_no_button.pressed.connect(_answer.bind(false))
	_yes_button.pressed.connect(_answer.bind(true))

	_panel.visible = false
	_set_confirm_mode(false)


## 显示一条通知；已经显示时直接替换内容。
func show_notice(
	message: String, title: String = "提示", ok_text: String = "确认", args: Array = []
) -> void:
	if not is_instance_valid(_panel):
		return
	_set_confirm_mode(false)
	_apply_text(message, title, args)
	_ok_button.text = tr(ok_text)
	_present()


## 显示两按钮确认（默认答案是「否」）：await answered 拿结果。
func show_confirm(
	message: String,
	title: String = "提示",
	no_text: String = "否",
	yes_text: String = "是",
	args: Array = []
) -> void:
	if not is_instance_valid(_panel):
		return
	_set_confirm_mode(true)
	_apply_text(message, title, args)
	_no_button.text = tr(no_text)
	_yes_button.text = tr(yes_text)
	_present()
	# 手柄/键盘下默认焦点落在「否」；鼠标模式里 UiFocusPolicy 会把按钮设为不可聚焦，grab 无效也无害。
	_no_button.grab_focus()


## 关闭通知面板（点确认 / 点否或是 / 代码调用都会走这里）。
func hide_notice() -> void:
	if not is_instance_valid(_panel) or not _panel.visible:
		return
	if _panel.has_method("stop_animation"):
		_panel.call("stop_animation")
	_panel.visible = false
	_set_confirm_mode(false)
	closed.emit()


func is_notice_visible() -> bool:
	return is_instance_valid(_panel) and _panel.visible


## 确认框里点了按钮：先关面板再发结果（避免调用方在回调里又弹一个通知时被 hide 掉）。
func _answer(accepted: bool) -> void:
	if not is_instance_valid(_panel) or not _panel.visible:
		return
	hide_notice()
	answered.emit(accepted)


## 只在 show_confirm() 时显示「否 / 是」，其余时候用单个「确认」。
func _set_confirm_mode(value: bool) -> void:
	if is_instance_valid(_ok_button):
		_ok_button.visible = not value
	if is_instance_valid(_button_row):
		_button_row.visible = value


func _apply_text(message: String, title: String, args: Array) -> void:
	var text: String = tr(message)
	if not args.is_empty():
		text = text % args
	_title_label.text = tr(title)
	_message_label.text = text


func _present() -> void:
	_panel.visible = true
	# 掉落 + 两次反弹（动画在 notice_panel.gd 里）
	if _panel.has_method("play_drop_in"):
		_panel.call("play_drop_in")
