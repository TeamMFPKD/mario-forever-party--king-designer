extends CanvasLayer

## 全局“纯信息通知”面板（autoload 名：Notice）。
##
## 只用来展示一段信息和一个确认按钮，没有分支选择；面板铺满整个屏幕，
## 显示期间会吃掉所有鼠标点击，点“确认”后关闭。
##
## 用法：
##   Notice.show_notice("游戏已经开始，无法加入该房间。", "游戏进行中")
##   Notice.show_notice("端口 %d 已被占用。", "创建房间失败", "确认", [local_port])
##   Notice.hide_notice()                      # 代码里主动关闭
##   await Notice.closed                        # 等玩家点确认
##
## 说明：
## - [param message] / [param title] / [param ok_text] 会先经过 tr()，再按 [param args] 格式化，
##   所以调用处传中文原文即可，翻译表里按 msgid 配置。
## - 节点树在 _ready 里由 notice_panel.tscn 实例化，这样 autoload 条目可以指向 .gd，
##   其它脚本调用 Notice.xxx() 时静态类型不会退化成 Node。

signal closed

const PANEL_SCENE: PackedScene = preload("res://ui/notice_panel.tscn")

## 画在其它 UI 之上（标题界面最高用的是 z_index 600，这里用独立 CanvasLayer）
const CANVAS_LAYER: int = 128

var _panel: Control
var _title_label: Label
var _message_label: Label
var _ok_button: Button

func _ready() -> void:
	layer = CANVAS_LAYER
	# 暂停时也要能显示/关闭
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = PANEL_SCENE.instantiate() as Control
	add_child(_panel)

	_title_label = _panel.get_node("%TitleLabel") as Label
	_message_label = _panel.get_node("%MessageLabel") as Label
	_ok_button = _panel.get_node("%OkButton") as Button
	_ok_button.pressed.connect(hide_notice)

	_panel.visible = false

## 显示一条通知；已经显示时直接替换内容。
func show_notice(message: String, title: String = "提示", ok_text: String = "确认", args: Array = []) -> void:
	if not is_instance_valid(_panel):
		return

	var text: String = tr(message)
	if not args.is_empty():
		text = text % args

	_title_label.text = tr(title)
	_message_label.text = text
	_ok_button.text = tr(ok_text)

	_panel.visible = true
	# 按钮统一不接收键盘焦点（见 NoButtonFocus），这里不再 grab_focus

## 关闭通知面板（点确认或代码调用都会走这里）。
func hide_notice() -> void:
	if not is_instance_valid(_panel) or not _panel.visible:
		return
	_panel.visible = false
	closed.emit()

func is_notice_visible() -> bool:
	return is_instance_valid(_panel) and _panel.visible
