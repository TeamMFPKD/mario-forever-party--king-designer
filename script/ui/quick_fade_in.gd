class_name QuickFadeIn
extends RefCounted

# meta 里取出来的是 Variant，收窄成 Tween 需要 as 强转；项目把 unsafe_cast 当错误处理。
@warning_ignore_start("unsafe_cast")

## 贴图（封面）异步加载到位时的「快速淡入」：把目标 Control 的 alpha 从 0 推到 1，
## 避免截图在某一帧里硬弹出来。
##
## 只在拿到贴图后补一小段透明度过渡，够短（默认 0.16s），看不出「在播动画」，
## 只把硬切的突兀磨平；重复调用会掐掉上一次过渡，从 0 重新播。
##
## 用法：
##   QuickFadeIn.play(texture_rect)
##
## 只动 `modulate:a`，不碰 `self_modulate`——收藏卡片的悬停变色用的是
## `self_modulate`，两者互不影响。

## 默认时长（秒）。
const DEFAULT_DURATION: float = 0.16
## 过渡曲线：先快后慢，收尾不拖沓。
const FADE_TRANS: Tween.TransitionType = Tween.TRANS_QUAD
const FADE_EASE: Tween.EaseType = Tween.EASE_OUT
## 正在播放的 Tween 记在目标的 meta 上：目标被重复填充贴图时先 kill 旧的，
## 避免两条 tween 同时写 `modulate:a` 打架。
const TWEEN_META: StringName = &"_quick_fade_in_tween"


## 从全透明开始淡入到不透明。目标已释放/为空时静默返回。
static func play(target: CanvasItem, duration: float = DEFAULT_DURATION) -> void:
	if target == null or not is_instance_valid(target):
		return
	_kill_running(target)
	_set_alpha(target, 0.0)
	if duration <= 0.0:
		_set_alpha(target, 1.0)
		return
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "modulate:a", 1.0, duration) \
		.set_trans(FADE_TRANS).set_ease(FADE_EASE)
	target.set_meta(TWEEN_META, tween)
	tween.finished.connect(_on_finished.bind(target, tween))


## 收尾：把 alpha 固定成 1 并清掉 meta。目标可能在动画期间被释放（列表重排、
## 离开房间），所以先验活再写。
static func _on_finished(target: CanvasItem, tween: Tween) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_meta(TWEEN_META) and target.get_meta(TWEEN_META) != tween:
		# 已经有更新的一轮淡入接手，别把它的起点抹掉
		return
	target.remove_meta(TWEEN_META)
	_set_alpha(target, 1.0)


static func _kill_running(target: CanvasItem) -> void:
	# 注意：get_meta 的默认值参数传 null 等于"没给默认值"，缺 key 时照样报错，
	# 所以先用 has_meta 挡一层。
	if not target.has_meta(TWEEN_META):
		return
	var previous: Variant = target.get_meta(TWEEN_META)
	if previous is Tween:
		var old: Tween = previous as Tween
		if old.is_valid():
			old.kill()
		target.remove_meta(TWEEN_META)


## 只改 alpha，保留已有的 RGB（卡片悬停时 self_modulate 在用，modulate 一般仍是白色）。
static func _set_alpha(target: CanvasItem, alpha: float) -> void:
	var color: Color = target.modulate
	color.a = alpha
	target.modulate = color
