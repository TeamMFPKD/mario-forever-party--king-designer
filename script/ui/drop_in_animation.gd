extends Node
class_name DropInAnimation

## 「从屏幕上方掉落 + 两次反弹」的通用面板动画。
##
## 参数与全局通知面板 ui/notice_panel.tscn 完全一致，标题页「组织游戏 / 加入游戏」
## 和通知弹窗共用这一份实现，保证观感一致。
##
## 位移只叠加在目标节点的 position.y 上，动画前后都回到静止位置，
## 不会破坏容器原本的居中布局。
##
## 用法：
## - 挂成面板的子节点，target_path 指要位移的 Control（通常就是父面板）；
## - panel_path 指真正带底板的那块面板，用来算起始高度（留空则用 target）；
## - watch_path 指监听显隐的节点：一显示自动播、隐藏立即复位；留空则由外部
##   显式调用 play_drop_in() / stop_animation()。

## 掉落时长（秒）：短促、带加速，模拟自由落体
const DROP_TIME: float = 0.26
## 两次反弹：上冲幅度(px) 与往返时长(秒)，依次衰减
const BOUNCE_HEIGHTS: PackedFloat32Array = [46.0, 18.0]
const BOUNCE_TIMES: PackedFloat32Array = [0.22, 0.16]
## 起始位置额外上抬的余量，保证面板完全在屏幕之外
const START_MARGIN: float = 40.0
## 拿不到视口高度时的兜底值（标题页逻辑分辨率的 1080）
const FALLBACK_VIEW_H: float = 1080.0

@export var target_path: NodePath = ^".."
@export var panel_path: NodePath = ^""
@export var watch_path: NodePath = ^".."
## _ready 时 watch 已经可见也要播一次（标题页的两个页面初始隐藏，不需要）
@export var play_on_ready_visible: bool = false

var _target: Control
var _panel: Control
var _watch: CanvasItem
var _tween: Tween
## 面板静止时的 y，动画围绕它做偏移；每次播放前重新采样
var _rest_y: float = 0.0
## 是否已经把面板挪到半空，防止从未播放过的 stop_animation() 把布局写坏
var _has_offset: bool = false


func _ready() -> void:
	# 暂停时也要能正常播完（全局通知会在暂停时弹出）
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target = get_node_or_null(target_path) as Control
	if not panel_path.is_empty():
		_panel = get_node_or_null(panel_path) as Control
	else:
		_panel = _target
	if not watch_path.is_empty():
		_watch = get_node_or_null(watch_path) as CanvasItem
	if _target == null:
		push_warning("DropInAnimation: 找不到位移目标 %s" % target_path)
		return
	if _watch != null:
		_watch.visibility_changed.connect(_on_visibility_changed)
		if play_on_ready_visible and _watch.visible:
			play_drop_in()


## 播放掉落 + 两次反弹。重复调用会先掐掉上一次动画再从头播。
func play_drop_in() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_kill_tween()
	# 上一轮动画如果停在半空，先归位再采样静止位置
	if _has_offset:
		_reset_offset()
	_rest_y = _target.position.y

	var view_h: float = _target.get_viewport_rect().size.y
	if view_h <= 0.0:
		view_h = FALLBACK_VIEW_H
	var panel_h: float = _panel.size.y if _panel != null and _panel.size.y > 0.0 else view_h * 0.5
	# 面板垂直居中：中心离屏幕上沿 view_h/2，再加自身半高与余量，
	# 起始时整块面板刚好完全在屏幕上边缘之外。
	var start_y: float = _rest_y - (view_h * 0.5 + panel_h * 0.5 + START_MARGIN)
	_target.position.y = start_y
	_has_offset = true

	_tween = create_tween()
	# 显式给每段指定起始值：页面刚显示时 Control 会按 anchors 重排一次，
	# 把刚写进去的起始偏移抹掉；Tween 惰性采样起点就会误读成静止位置，
	# 整段动画看起来完全没动。from() 让每一帧都由 Tween 自己接管。
	# 1. 自由落体到落位点：加速下落
	_tween.tween_property(_target, "position:y", _rest_y, DROP_TIME) \
		.from(start_y) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 2. 两次反弹：先冲过头回到落位点
	for i: int in range(BOUNCE_HEIGHTS.size()):
		var up: float = BOUNCE_HEIGHTS[i]
		var half: float = BOUNCE_TIMES[i] * 0.5
		_tween.tween_property(_target, "position:y", _rest_y - up, half) \
			.from(_rest_y) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_target, "position:y", _rest_y, half) \
			.from(_rest_y - up) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_reset_offset)


## 立即停止动画并把位移归零（关闭弹窗时调用，避免下次打开从半空开始）。
func stop_animation() -> void:
	_kill_tween()
	if _has_offset:
		_reset_offset()


func _on_visibility_changed() -> void:
	if _watch == null or not is_instance_valid(_watch):
		return
	if _watch.visible:
		play_drop_in()
	else:
		stop_animation()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _reset_offset() -> void:
	_has_offset = false
	if _target != null and is_instance_valid(_target):
		_target.position.y = _rest_y
