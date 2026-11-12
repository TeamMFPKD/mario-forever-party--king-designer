extends MarginContainer

## 标题界面「使用须知」弹窗：首次进标题时整块面板从屏幕上方掉落，
## 落位后向上反弹两次，幅度与时长依次衰减（与 ui/notice_panel.tscn 的弹窗一致）。

signal notice_accepted

@export var refuse_button: Button
@export var accept_button: Button

var config: ConfigFile

const USER_NOTICE_SECTION: String = "user_notice_v3"

## 掉落时长（秒）：短促、带加速，模拟自由落体
const DROP_TIME: float = 0.26
## 两次反弹的参数：key = 反弹上冲的幅度(px)，value = 该次反弹的往返时长(秒)
const BOUNCE_HEIGHTS: PackedFloat32Array = [46.0, 18.0]
const BOUNCE_TIMES: PackedFloat32Array = [0.22, 0.16]

## 真正带底板的面板。UserNotice 自己是 MarginContainer，会给直接子节点重排位置，
## 所以位移加在 DropRoot 下的面板上，容器布局不受影响。
var _panel: Control
var _tween: Tween

func _ready() -> void:
	visible = true
	_panel = get_node_or_null("DropRoot/UiPanel") as Control
	config = GameConfig.get("config")
	var accept: bool = config.get_value(USER_NOTICE_SECTION, "accept", false)
	if accept:
		emit_signal("notice_accepted")
		visible = false
		return
	refuse_button.pressed.connect(_on_refuse_button_pressed)
	accept_button.pressed.connect(_on_accept_button_pressed)
	play_drop_in()

## 播放掉落 + 两次反弹。重复调用会先掐掉上一次动画再从头播。
func play_drop_in() -> void:
	if _panel == null:
		return
	_stop_tween()
	# 布局还没算完时先整块藏到屏幕上方，避免动画开始前闪一帧静止的面板
	_panel.position.y = -get_viewport_rect().size.y
	# 等 GameRoomSize 按视口尺寸把自己撑开，再按真实高度算起始位置
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_panel) or not _panel.is_inside_tree():
		return

	_panel.position.y = 0.0
	var panel_h: float = _panel.size.y
	if panel_h <= 0.0:
		return
	# 面板在 DropRoot 里静止时距离 UserNotice 顶部有一段边距，起始高度要连它一起算，
	# 否则面板还会露出屏幕下沿一截
	var top_inset: float = _panel.global_position.y - global_position.y
	_panel.position.y = -(top_inset + panel_h + 40.0)

	_tween = create_tween()
	# 1. 自由落体到落位点：加速下落
	_tween.tween_property(_panel, "position:y", 0.0, DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 2. 两次反弹：先冲过头再回到落位点
	for i: int in range(BOUNCE_HEIGHTS.size()):
		var up: float = BOUNCE_HEIGHTS[i]
		var half: float = BOUNCE_TIMES[i] * 0.5
		_tween.tween_property(_panel, "position:y", -up, half) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_panel, "position:y", 0.0, half) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_reset_offset)

## 立即停止动画并把位移归零（关闭弹窗时调用，避免下次打开从半空开始）。
func stop_animation() -> void:
	_stop_tween()
	_reset_offset()

func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _reset_offset() -> void:
	if _panel != null:
		_panel.position.y = 0.0

func _on_refuse_button_pressed() -> void:
	get_tree().quit()
	print("[user_notice.gd] 拒绝并退出")

func _on_accept_button_pressed() -> void:
	stop_animation()
	visible = false
	config.set_value(USER_NOTICE_SECTION, "accept", true)
	GameConfig.call("save")
