extends Node
class_name LetterBounceAnimation

## 逐字「弹跳入场」动画：GAME CLEAR 专用。
##
## 观感：字母直接出现在自己的目标位置（不像 GAME OVER 那样从遮罩上沿掉进来），
## 带一个初始 y 速度，受重力影响回落，重新落到目标 y 时反弹（速度按衰减系数变小），
## 反复几次后停在目标位置。
##
## 和标题画面的 script/title/animation/ui_animation_fall.gd 是同一套思路：
## 速度积分 + 重力 + 目标 y 当地面 + 反弹衰减。区别是那边整块标题一起落，
## 这边一个字一个字地各自弹。
##
## 位移写在 offset 上而不是 position 上：字母是槽位的满幅锚定子节点，
## 写 offset 表示「相对槽位顶边抬高多少」，之后容器重排槽位也不会把偏移洗掉
## （写 position 会被重排抹平，字母会停在半空）。
##
## 用法：挂成字母 Label 的子节点，target_path 指向该 Label（默认即父节点）。
## 没开始播放前字母是透明的，播放时淡入；逐字错峰由 start_delay 控制。

## 被动画的节点（一般是字母 Label）。
@export var target_path: NodePath = ^".."
## 初始上跳速度（px/秒，正值向上）。
@export var initial_velocity_y: float = 620.0
## 重力加速度（px/秒²），恒向下。
@export var gravity: float = 4000.0
## 每次反弹的速度衰减系数（0~1，越小衰减越快）。
@export var damping: float = 0.55
## 速度小到该值（px/秒）以下就算稳定，停在目标位置。
@export var settle_speed: float = 40.0
## 开始前先等这么久（逐字错峰）。
@export var start_delay: float = 0.0
## 出现时的淡入时长（秒）。
@export var fade_in_time: float = 0.1

var _target: Control
## 字母的静止偏移（场景里的原始值），位移在它上面叠加。
var _base_offset_top: float = 0.0
var _base_offset_bottom: float = 0.0
## 字母相对目标位置的高度（像素，正值表示在目标位置上方）。
var _hop: float = 0.0
## 上跳速度（px/秒，正值向上）。
var _velocity: float = 0.0
var _running: bool = false
var _delay_left: float = 0.0
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target = get_node_or_null(target_path) as Control
	if _target == null:
		push_warning("LetterBounceAnimation: 找不到动画目标 %s" % target_path)
		return
	# 原始偏移先存下来：位移都是在它上面叠加。
	_base_offset_top = _target.offset_top
	_base_offset_bottom = _target.offset_bottom
	# 播放前先透明：淡入由本脚本负责，逐字错峰才看得出「一个一个出现」。
	_target.modulate.a = 0.0


## 开始播放。start_delay > 0 时先等一会儿再动。
func play() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_hop = 0.0
	_velocity = initial_velocity_y
	_delay_left = start_delay
	_running = true
	if _delay_left <= 0.0:
		_begin_motion()


## 立即停止并把字母归位（透明结束、停回目标位置）。
func stop() -> void:
	_running = false
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	if _target != null and is_instance_valid(_target):
		_target.modulate.a = 1.0
		_apply()


## 动画是否已经结束（停稳，或还没开始播）。
func is_finished() -> bool:
	return not _running


func _process(delta: float) -> void:
	if not _running:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		if _delay_left <= 0.0:
			_begin_motion()
		return
	_step(delta)


## 淡入，同时把初速度交出去。
func _begin_motion() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_target, "modulate:a", 1.0, fade_in_time)


## 一帧的物理推进：先按当前速度位移，再判地面反弹，最后累加重力。
## 顺序和标题画面那套一致，落位判定放在累加重力之前，反弹后的向上速度不会被立刻抵消。
func _step(delta: float) -> void:
	_hop += _velocity * delta
	if _hop <= 0.0:
		# 落回目标高度：反弹，速度按衰减系数变小
		_hop = 0.0
		_velocity = -_velocity * damping
		if absf(_velocity) < settle_speed:
			_velocity = 0.0
			_apply()
			_running = false
			return
	_velocity -= gravity * delta
	_apply()


## 把当前高度写进偏移：抬高 _hop 像素就是往目标位置上方挪。
func _apply() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_target.offset_top = _base_offset_top - _hop
	_target.offset_bottom = _base_offset_bottom - _hop
