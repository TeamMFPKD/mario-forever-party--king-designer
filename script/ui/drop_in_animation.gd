extends Node
class_name DropInAnimation

## 「从屏幕上方掉落」的通用面板动画，两种观感：
## - BOUNCE（默认）：自由落体砸到落位点，向上弹两次，幅度依次衰减；
## - SMOOTH：三次插值一路减速落到落位点，落位瞬间速度归零，不反弹、不震动。
##
## 标题页「组织游戏 / 加入游戏」「使用须知」用 SMOOTH，全局通知弹窗
## ui/notice_panel.tscn 与冒险结算标题用 BOUNCE，共用这一份实现。
##
## 位移只叠加在目标节点的 position.y 上，动画前后都回到静止位置，
## 不会破坏容器原本的居中布局。
##
## 用法：
## - 挂成面板的子节点，target_path 指要位移的 Control（通常就是父面板）；
## - panel_path 指真正带底板的那块面板，用来算起始高度（留空则用 target）；
## - watch_path 指监听显隐的节点：一显示自动播、隐藏立即复位；留空则由外部
##   显式调用 play_drop_in() / stop_animation()。

## 进入 / 退出时的观感。
enum EnterStyle {
	## 自由落体 + 两次反弹。
	BOUNCE,
	## 三次插值平滑落位，落位后不回弹。
	SMOOTH,
}

## 掉落时长（秒）：短促、带加速，模拟自由落体
const DROP_TIME: float = 0.26
## 两次反弹：上冲幅度(px) 与往返时长(秒)，依次衰减
const BOUNCE_HEIGHTS: PackedFloat32Array = [46.0, 18.0]
const BOUNCE_TIMES: PackedFloat32Array = [0.22, 0.16]
## 起始位置额外上抬的余量，保证面板完全在屏幕之外
const START_MARGIN: float = 40.0
## 拿不到视口高度时的兜底值（标题页逻辑分辨率的 1080）
const FALLBACK_VIEW_H: float = 1080.0
## SMOOTH 变种的缓动：三次插值 + 减速到零（落位那一头速度恰好为 0，所以不会震）
const SMOOTH_TRANS: Tween.TransitionType = Tween.TRANS_CUBIC
const SMOOTH_EASE: Tween.EaseType = Tween.EASE_OUT

@export var target_path: NodePath = ^".."
@export var panel_path: NodePath = ^""
@export var watch_path: NodePath = ^".."
## _ready 时 watch 已经可见也要播一次（标题页的两个页面初始隐藏，不需要）
@export var play_on_ready_visible: bool = false
## 起始上抬距离（像素）。> 0 时不再按视口高度推算，改用这个值：
## 字母逐字掉落这类只需要"从裁剪框上沿落进来"的场景用它，否则会从屏幕外很远开始掉。
@export var drop_distance: float = 0.0
## 播放前的等待时间（秒）。批量调用时由调用方给每个实例设置，实现逐字错峰。
@export var start_delay: float = 0.0
## 进入 / 退出的观感，见 EnterStyle。
@export var enter_style: EnterStyle = EnterStyle.BOUNCE
## SMOOTH 变种的下落时长（秒）。比 DROP_TIME 长一点：少了两次反弹，
## 落位那一下只能靠减速本身收尾，太快会显得"啪"地砸住。
@export var smooth_drop_time: float = 0.36

## 退出动画播完（此时面板停在屏幕外，由调用方决定何时隐藏）
signal drop_out_finished

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


## 播放进入动画（按 enter_style 选观感）。重复调用会先掐掉上一次动画再从头播。
func play_drop_in() -> void:
	if enter_style == EnterStyle.SMOOTH:
		play_smooth_drop_in()
	else:
		_play_bounce_drop_in()


## 平滑变种：三次插值从屏幕上沿之外落到落位点，落位瞬间速度归零，不反弹、不震动。
func play_smooth_drop_in() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_kill_tween()
	# 上一轮动画如果停在半空，先归位再采样静止位置
	if _has_offset:
		_reset_offset()
	_rest_y = _target.position.y

	var start_y: float = _rest_y - _smooth_fall()
	_target.position.y = start_y
	_has_offset = true

	_tween = create_tween()
	# 逐字错峰：先在空中等一会儿再下落（起始位置已在屏幕外，看不见）。
	if start_delay > 0.0:
		_tween.tween_interval(start_delay)
	# 显式给每段指定起始值：页面刚显示时 Control 会按 anchors 重排一次，
	# 把刚写进去的起始偏移抹掉；Tween 惰性采样起点就会误读成静止位置。
	_tween.tween_property(_target, "position:y", _rest_y, smooth_drop_time) \
		.from(start_y) \
		.set_trans(SMOOTH_TRANS).set_ease(SMOOTH_EASE)
	_tween.tween_callback(_reset_offset)


## 反弹变种：自由落体砸到落位点，再向上弹两次、幅度依次衰减。
func _play_bounce_drop_in() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_kill_tween()
	# 上一轮动画如果停在半空，先归位再采样静止位置
	if _has_offset:
		_reset_offset()
	_rest_y = _target.position.y

	var start_y: float = _rest_y - _bounce_fall()
	_target.position.y = start_y
	_has_offset = true

	_tween = create_tween()
	# 逐字错峰：先在空中等一会儿再下落（起始位置已在裁剪框外，看不见）。
	if start_delay > 0.0:
		_tween.tween_interval(start_delay)
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


## 掉落的反向：加速飞回屏幕上方。
##
## 播完只发 drop_out_finished，**不自己隐藏节点** —— 调用方（如标题页页面管理器）
## 需要在这之前继续让玩家看到面板飞出去，并且可能因为重开同一页而取消隐藏。
func play_drop_out() -> void:
	if _target == null or not is_instance_valid(_target):
		drop_out_finished.emit()
		return
	_kill_tween()
	# 从没播过进入动画时 _rest_y 还没采样，用当前位置兜底
	if not _has_offset:
		_rest_y = _target.position.y
	# 退出沿用与进入同一套观感：SMOOTH 用同样的三次曲线与时长反向飞出去。
	var smooth: bool = enter_style == EnterStyle.SMOOTH
	var fall: float = _smooth_fall() if smooth else _bounce_fall()
	var time: float = smooth_drop_time if smooth else DROP_TIME
	var trans: Tween.TransitionType = SMOOTH_TRANS if smooth else Tween.TRANS_QUAD
	_has_offset = true
	_tween = create_tween()
	_tween.tween_property(_target, "position:y", _rest_y - fall, time) \
		.from(_target.position.y) \
		.set_trans(trans).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_emit_drop_out_finished)


func _emit_drop_out_finished() -> void:
	_tween = null
	drop_out_finished.emit()


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


func _view_height() -> float:
	var view_h: float = _target.get_viewport_rect().size.y
	if view_h <= 0.0:
		view_h = FALLBACK_VIEW_H
	return view_h


## 起始距离：反弹变种按"面板垂直居中"推算，整块面板刚好完全在屏幕上边缘之外。
func _bounce_fall() -> float:
	if drop_distance > 0.0:
		return drop_distance
	var view_h: float = _view_height()
	var panel_h: float = _panel.size.y if _panel != null and _panel.size.y > 0.0 else view_h * 0.5
	return view_h * 0.5 + panel_h * 0.5 + START_MARGIN


## 起始距离：平滑变种直接读面板自身的位置与高度，让面板整体刚好停在屏幕上沿之外。
##
## 不能沿用"按视口居中推算"——使用须知那种铺满屏幕的面板静止时就贴着屏幕上沿，
## 按视口推算会多飞出去一大截，等于用同样的时间跑更远的路（观感变成一闪而过）。
func _smooth_fall() -> float:
	if drop_distance > 0.0:
		return drop_distance
	var view_h: float = _view_height()
	if _panel == null or not is_instance_valid(_panel) or _panel.size.y <= 0.0:
		# 拿不到面板（或布局还没算完）时退化为按视口推算
		return view_h * 0.5 + _target.size.y * 0.5 + START_MARGIN
	return maxf(_panel.global_position.y + _panel.size.y + START_MARGIN, START_MARGIN)
