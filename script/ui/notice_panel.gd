extends Control

## 通知弹窗的视觉表现层（notice_manager.gd 负责内容与显隐，本脚本只管动画）。
##
## 动画：整块面板从屏幕上方快速掉落至屏幕中央，落位后向上反弹两次，
## 两次反弹的幅度与时长依次衰减，形成自然的阻尼感。
##
## 说明：
## - 位移作用在 DropRoot 上，而不是 CenterContainer 本身，这样 CenterContainer
##   的居中布局不受影响，动画只叠加 y 偏移。
## - 用 process_mode = ALWAYS，保证 get_tree().paused 时动画照常播放。

## 掉落时长（秒）：短促、带加速，模拟自由落体
const DROP_TIME: float = 0.26
## 两次反弹的参数：key = 反弹上冲的幅度(px)，value = 该次反弹的往返时长(秒)
const BOUNCE_HEIGHTS: PackedFloat32Array = [46.0, 18.0]
const BOUNCE_TIMES: PackedFloat32Array = [0.22, 0.16]

var _drop_root: Control
## 真正带底板的那块面板，用来算起始高度（DropRoot 是全屏铺满的）
var _ui_panel: Control
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_drop_root = get_node_or_null("DropRoot") as Control
	_ui_panel = get_node_or_null("DropRoot/CenterContainer/UiPanel") as Control


## 播放掉落 + 两次反弹。重复调用会先掐掉上一次动画再从头播。
func play_drop_in() -> void:
	if _drop_root == null:
		return
	_kill_tween()

	var view_h: float = size.y
	if view_h <= 0.0:
		view_h = get_viewport_rect().size.y

	# 起始位置：整块面板完全在屏幕上边缘之外。
	# 面板垂直居中，所以中心点离屏幕上沿是 view_h/2，再加上面板自身高度的一半。
	var panel_h: float = _ui_panel.size.y if _ui_panel != null else 0.0
	if panel_h <= 0.0:
		panel_h = view_h * 0.5
	var start_y: float = -(view_h * 0.5 + panel_h * 0.5 + 40.0)
	_drop_root.position.y = start_y

	_tween = create_tween()
	# 1. 自由落体到落位点：加速下落
	_tween.tween_property(_drop_root, "position:y", 0.0, DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 2. 两次反弹：先冲过头回到落位点
	for i: int in range(BOUNCE_HEIGHTS.size()):
		var up: float = BOUNCE_HEIGHTS[i]
		var half: float = BOUNCE_TIMES[i] * 0.5
		_tween.tween_property(_drop_root, "position:y", -up, half) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_drop_root, "position:y", 0.0, half) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_reset_offset)


## 立即停止动画并把位移归零（关闭弹窗时调用，避免下次打开从半空开始）。
func stop_animation() -> void:
	_kill_tween()
	_reset_offset()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _reset_offset() -> void:
	if _drop_root != null:
		_drop_root.position.y = 0.0
