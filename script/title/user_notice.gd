extends MarginContainer

## 标题界面「使用须知」弹窗：首次进标题时整块面板从屏幕上方平滑落下。
##
## 动画由公共组件 DropInAnimation 的 SMOOTH 观感提供：三次插值一路减速到落位点，
## 落位后不回弹、不震动（与「组织游戏 / 加入游戏」两页一致）。
##
## 说明：
## - 位移作用在 DropRoot/UiPanel 上，而不是 UserNotice 这个 MarginContainer 本身，
##   否则会被容器重新布局抹掉；
## - 面板刚进场景时布局还没按视口撑开，先把它藏到屏幕上方等两帧，再按真实高度播。

signal notice_accepted

@export var refuse_button: Button
@export var accept_button: Button

var config: ConfigFile

const USER_NOTICE_SECTION: String = "user_notice_v3"

## 真正带底板的面板。UserNotice 自己是 MarginContainer，会给直接子节点重排位置，
## 所以位移加在 DropRoot 下的面板上，容器布局不受影响。
var _panel: Control
var _drop_in: DropInAnimation


func _ready() -> void:
	visible = true
	_panel = get_node_or_null("DropRoot/UiPanel") as Control

	config = GameConfig.get("config")
	var accept: bool = config.get_value(USER_NOTICE_SECTION, "accept", false)
	if accept:
		emit_signal("notice_accepted")
		visible = false
		return

	_drop_in = DropInAnimation.new()
	_drop_in.name = "DropInAnimation"
	_drop_in.target_path = ^"../DropRoot/UiPanel"
	_drop_in.panel_path = ^"../DropRoot/UiPanel"
	# 显隐由本脚本控制，动画也由这里显式触发
	_drop_in.watch_path = ^""
	_drop_in.enter_style = DropInAnimation.EnterStyle.SMOOTH
	add_child(_drop_in)

	refuse_button.pressed.connect(_on_refuse_button_pressed)
	accept_button.pressed.connect(_on_accept_button_pressed)
	play_drop_in()


## 播放平滑下落。重复调用会先掐掉上一次动画再从头播。
func play_drop_in() -> void:
	if _drop_in == null or _panel == null:
		return
	# 布局还没算完时先整块藏到屏幕上方，避免动画开始前闪一帧静止的面板
	_panel.position.y = -get_viewport_rect().size.y
	# 等 GameRoomSize 按视口尺寸把自己撑开，再按真实高度算起始位置
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_panel) or not _panel.is_inside_tree():
		return
	_panel.position.y = 0.0
	_drop_in.play_drop_in()


## 立即停止动画并把位移归零（关闭弹窗时调用，避免下次打开从半空开始）。
func stop_animation() -> void:
	if _drop_in != null:
		_drop_in.stop_animation()


func _on_refuse_button_pressed() -> void:
	get_tree().quit()
	print("[user_notice.gd] 拒绝并退出")


func _on_accept_button_pressed() -> void:
	stop_animation()
	visible = false
	config.set_value(USER_NOTICE_SECTION, "accept", true)
	GameConfig.call("save")
