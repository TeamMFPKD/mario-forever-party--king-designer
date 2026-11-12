extends CanvasLayer

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团过关转场（前端场景版）。
##
## 坐标系 = 关卡 SubViewport 的 2D 尺寸 640×480
## （SubViewport 1280×960 + size_2d_override 640×480 + stretch）。
## 根节点是 CanvasLayer，因此不受 LevelCamera 滚动影响，也不会画到主视口上。
##
## 结构见 adventure_clear_transition.tscn：
##   AdventureClearTransition (CanvasLayer, layer 60)
##   └─ Root (Control 640×480)
##      └─ Yellow (Node2D)              —— 划入/划出的黄色整块
##         ├─ YellowShape (Polygon2D)   —— 橙黄底 + 左右锯齿
##         ├─ Chain (Control)           —— 只露一条横缝，椭圆上下被裁掉
##         │   └─ LevelRow (Node2D)     —— 椭圆串
##         ├─ Player (AnimatedSprite2D) —— 马里奥，全程 jump 动画
##         └─ ProgressLabel (Label)     —— 第 N/M 关
##
## 时序：划入 → 地面停 0.2s → 跳一次（关卡串前进一格）→ 地面停 0.2s → 平移划出。

signal finished

const SLIDE_IN: float = 0.34
const HOLD_DURATION: float = 0.2
const JUMP_DURATION: float = 0.42
const SLIDE_OUT: float = 0.5

## 跳跃
const JUMP_HEIGHT: float = 42.0

## 椭圆行
const NODE_RX: float = 15.0
const NODE_RY: float = 13.0
const NODE_GAP: float = 68.0
const NODE_COUNT: int = 11
const ROW_Y: float = 300.0
const PLAYER_SLOT: int = 5

## 裁切带：只比椭圆高一点点，超出的连线被裁掉
const CLIP_HEIGHT: float = 30.0
const CLIP_INSET_X: float = 24.0

## 椭圆环与连线用同一个线宽，保持视觉统一
const RING_WIDTH: float = 2.0

## 左右淡出：阶梯数 × 每段宽度 = 单侧提前量（10 × 12 = 120px）
const FADE_STEPS: int = 10
const FADE_STEP_W: float = 12.0

## mario_small.png：17 列 x 2 行，单帧 32x66；脚底在帧内 y=65
const FRAME_W: float = 32.0
const FOOT_OFFSET: float = 65.0
const PLAYER_SCALE: float = 0.8
const PLAYER_X: float = 320.0

## LevelRow 是 Chain 的子节点，Chain 自带 CLIP_INSET_X 的左边距；
## 这里把行原点补回来，保证「椭圆中心 == 玩家 x」。
const ROW_ORIGIN_X: float = PLAYER_X - CLIP_INSET_X

## 视口设计尺寸
const VIEW_W: float = 640.0
const VIEW_H: float = 480.0

const YELLOW: Color = Color(1.0, 0.5019608, 0.0, 1.0)
const WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
## 锯齿：每 ZIGZAG_STEP 一个来回，半格走一半，水平深度取半格 → 斜边 45°
const ZIGZAG_STEP: float = 48.0
const ZIGZAG_DEPTH: float = ZIGZAG_STEP * 0.5

## 背景道具：跟着关卡串一起左移，但只走一半距离（视差）；完全移出画布左侧后才回收
const PROP_MOVE_SCALE: float = 0.5
## 划入 / 划出时道具自身的平移量 = NODE_GAP × 该系数
const PROP_SLIDE_SCALE: float = 4.0
const PROP_WRAP_LEFT: float = -48.0
const PROP_WRAP_SPAN: float = VIEW_W + 200.0

@onready var _yellow: Node2D = $Root/Yellow
@onready var _shape: Polygon2D = $Root/Yellow/YellowShape
@onready var _chain: Control = $Root/Yellow/Chain
@onready var _row: Node2D = $Root/Yellow/Chain/LevelRow
@onready var _props: Control = $Root/Yellow/Props
@onready var _player: AnimatedSprite2D = $Root/Yellow/Player
@onready var _progress: Label = $Root/Yellow/ProgressLabel

var _levels: Array[Node2D] = []
var _level_ids: Array[int] = []
var _level_labels: Array[Label] = []
var _base_x: Array[float] = []
var _prop_base: Array[Vector2] = []
## 跳跃开始时每颗道具的坐标；跳跃中用它 + 缓动位移，结束后落盘
var _prop_motion_base: Array[Vector2] = []

var _phase: int = 0
var _t: float = 0.0
var _start_level: int = 1
var _total_level: int = 10

var _player_rest_y: float = 0.0
var _chain_rest_y: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)
	_chain_rest_y = _chain.position.y
	_player_rest_y = ROW_Y - NODE_RY - FOOT_OFFSET * PLAYER_SCALE
	_build_shape()
	_build_row()
	_remember_props()
	_player.play(&"jump")
	if get_tree().current_scene == self:
		call_deferred("play", 3, 10)


## current：刚通过的关序号（1 起）；total <= 0 表示无尽团。
func play(current: int, total: int) -> void:
	_start_level = current
	_total_level = total
	_phase = 0
	_t = 0.0
	_yellow.position = Vector2(VIEW_W, 0.0)
	_yellow.modulate.a = 1.0
	_progress.modulate.a = 1.0
	_chain.position = Vector2(CLIP_INSET_X, _chain_rest_y)
	_player.position = Vector2(
		PLAYER_X - FRAME_W * PLAYER_SCALE * 0.5,
		_player_rest_y
	)
	_player.play(&"jump")
	_reset_row()
	_reset_props()
	_capture_prop_motion_base()
	_update_progress()
	visible = true
	set_process(true)


func _build_shape() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(VIEW_W, 0.0))

	# 右边缘（前导锯齿）：从上往下
	var y: float = 0.0
	var tooth: int = 0
	while y < VIEW_H:
		y = minf(y + ZIGZAG_STEP * 0.5, VIEW_H)
		var x: float = VIEW_W + ZIGZAG_DEPTH if tooth % 2 == 0 else VIEW_W
		points.append(Vector2(x, y))
		tooth += 1

	# 底边 → 左边缘（尾随锯齿）：从下往上
	points.append(Vector2(0.0, VIEW_H))
	var left_y: float = VIEW_H
	var left_tooth: int = 0
	while left_y > 0.0:
		left_y = maxf(left_y - ZIGZAG_STEP * 0.5, 0.0)
		var left_x: float = -ZIGZAG_DEPTH if left_tooth % 2 == 0 else 0.0
		points.append(Vector2(left_x, left_y))
		left_tooth += 1

	_shape.polygon = points


func _build_row() -> void:
	_row.position = Vector2(ROW_ORIGIN_X, CLIP_HEIGHT * 0.5)
	var index: int = 0
	while index < NODE_COUNT:
		var holder: Node2D = _make_level_node(0)
		_row.add_child(holder)
		_levels.append(holder)
		_level_ids.append(0)
		_level_labels.append(holder.get_node("IndexLabel") as Label)
		_base_x.append(0.0)
		index += 1
	_build_fade_masks()


## 在裁剪带的左右边缘叠上「橙黄 + 递减 alpha」的阶梯遮罩：
## 叠在橙黄底上隐形，叠在白圈/白线上等价于把可见度按台阶降下去。
func _build_fade_masks() -> void:
	var chain_width: float = VIEW_W - CLIP_INSET_X * 2.0
	var index: int = 0
	while index < FADE_STEPS:
		var mask_alpha: float = 1.0 - float(index) / float(FADE_STEPS)
		var left_mask: ColorRect = _make_fade_mask(mask_alpha)
		left_mask.position = Vector2(float(index) * FADE_STEP_W, 0.0)
		left_mask.size = Vector2(FADE_STEP_W, CLIP_HEIGHT)
		_chain.add_child(left_mask)

		var right_mask: ColorRect = _make_fade_mask(mask_alpha)
		right_mask.position = Vector2(chain_width - FADE_STEP_W * float(index + 1), 0.0)
		right_mask.size = Vector2(FADE_STEP_W, CLIP_HEIGHT)
		_chain.add_child(right_mask)
		index += 1


func _make_fade_mask(mask_alpha: float) -> ColorRect:
	var mask: ColorRect = ColorRect.new()
	mask.color = Color(YELLOW, mask_alpha)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mask


## 记下背景道具的初始位置，重播时复位。
func _remember_props() -> void:
	_prop_base.clear()
	for child: Node in _props.get_children():
		var prop: Node2D = child as Node2D
		if prop != null:
			_prop_base.append(prop.position)


func _reset_props() -> void:
	_props.position = Vector2.ZERO
	_prop_motion_base.clear()
	var index: int = 0
	while index < _prop_base.size():
		(_props.get_child(index) as Node2D).position = _prop_base[index]
		index += 1


## 跳跃开始前记下道具当前位置，作为这一跳的起点。
func _capture_prop_motion_base() -> void:
	_prop_motion_base.clear()
	for child: Node in _props.get_children():
		var prop: Node2D = child as Node2D
		if prop != null:
			_prop_motion_base.append(prop.position)


## 跳跃中：每颗道具按同一个缓动位移左移（容器与裁切框保持不动）。
## 位置取整到整像素，避免 2× 最近邻放大时描边像素闪动。
func _apply_prop_shift(shift: float) -> void:
	var index: int = 0
	while index < _prop_motion_base.size():
		var prop: Node2D = _props.get_child(index) as Node2D
		prop.position.x = roundf(_prop_motion_base[index].x - shift)
		index += 1


## 阶段结束：位移落盘，并把完全移出画布左侧的道具远距离回收到右侧（不会在画面里瞬移）。
func _settle_props(amount: float) -> void:
	var index: int = 0
	while index < _prop_motion_base.size():
		var prop: Node2D = _props.get_child(index) as Node2D
		var x: float = _prop_motion_base[index].x - amount
		if x < PROP_WRAP_LEFT:
			x += PROP_WRAP_SPAN
		prop.position.x = x
		_prop_motion_base[index] = prop.position
		index += 1


func _reset_row() -> void:
	var index: int = 0
	while index < _levels.size():
		_base_x[index] = float(index - PLAYER_SLOT) * NODE_GAP
		_levels[index].position = Vector2(_base_x[index], 0.0)
		var level_id: int = _start_level + index - PLAYER_SLOT
		_level_ids[index] = level_id
		_level_labels[index].text = str(level_id) if level_id >= 1 else ""
		index += 1


func _update_progress() -> void:
	if _total_level > 0:
		_progress.text = "第 %d/%d 关" % [_start_level, _total_level]
	else:
		_progress.text = "已通过 %d 关" % _start_level


func _make_level_node(level_index: int) -> Node2D:
	var holder: Node2D = Node2D.new()
	holder.name = "Level_%d" % level_index

	var line: Line2D = Line2D.new()
	line.points = PackedVector2Array([
		Vector2(NODE_RX, 0.0),
		Vector2(NODE_GAP - NODE_RX, 0.0),
	])
	line.width = RING_WIDTH
	line.default_color = WHITE
	holder.add_child(line)

	var outer: Polygon2D = Polygon2D.new()
	outer.polygon = _ellipse_points(NODE_RX, NODE_RY)
	outer.color = WHITE
	holder.add_child(outer)

	var inner: Polygon2D = Polygon2D.new()
	inner.polygon = _ellipse_points(NODE_RX - RING_WIDTH, NODE_RY - RING_WIDTH)
	inner.color = YELLOW
	holder.add_child(inner)

	var label: Label = Label.new()
	label.name = "IndexLabel"
	label.text = str(level_index)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", WHITE)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(NODE_RX * 2.0, NODE_RY * 2.0)
	label.position = Vector2(-NODE_RX, -NODE_RY)
	holder.add_child(label)

	return holder


func _ellipse_points(rx: float, ry: float, segments: int = 28) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var index: int = 0
	while index < segments:
		var angle: float = TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
		index += 1
	return points


func _ease_out_cubic(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func _ease_in_cubic(k: float) -> float:
	return k * k * k


func _ease_in_out_cubic(k: float) -> float:
	if k < 0.5:
		return 4.0 * k * k * k
	var f: float = 1.0 - k
	return 1.0 - 4.0 * f * f * f


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			_phase_slide_in()
		1, 3:
			_phase_hold()
		2:
			_phase_jump()
		4:
			_phase_slide_out()


func _phase_slide_in() -> void:
	var k: float = clampf(_t / SLIDE_IN, 0.0, 1.0)
	var e: float = _ease_out_cubic(k)

	# 纯水平划入：纵向位置保持不变
	_yellow.position.x = VIEW_W * (1.0 - e)
	_apply_prop_shift(NODE_GAP * PROP_SLIDE_SCALE * e)

	if k >= 1.0:
		_settle_props(NODE_GAP * PROP_SLIDE_SCALE)
		_advance_phase()


func _phase_hold() -> void:
	_player.position.y = _player_rest_y
	if _t >= HOLD_DURATION:
		_advance_phase()


func _phase_jump() -> void:
	var k: float = clampf(_t / JUMP_DURATION, 0.0, 1.0)
	var e: float = _ease_in_out_cubic(k)

	_player.position.y = _player_rest_y - JUMP_HEIGHT * 4.0 * k * (1.0 - k)

	var shift: float = NODE_GAP * e
	_apply_prop_shift(shift * PROP_MOVE_SCALE)
	var index: int = 0
	while index < _levels.size():
		_levels[index].position.x = _base_x[index] - shift
		index += 1

	if k >= 1.0:
		var span: float = NODE_GAP * float(NODE_COUNT)
		var wrap_limit: float = CLIP_INSET_X - PLAYER_X - NODE_GAP
		index = 0
		while index < _levels.size():
			_base_x[index] -= NODE_GAP
			if _base_x[index] < wrap_limit:
				_base_x[index] += span
				_level_ids[index] += NODE_COUNT
				_level_labels[index].text = str(_level_ids[index])
			_levels[index].position.x = _base_x[index]
			index += 1

		_player.position.y = _player_rest_y
		_settle_props(NODE_GAP * PROP_MOVE_SCALE)
		_advance_phase()


func _phase_slide_out() -> void:
	var k: float = clampf(_t / SLIDE_OUT, 0.0, 1.0)
	var e: float = _ease_in_cubic(k)

	_yellow.position.x = -VIEW_W * e
	_apply_prop_shift(NODE_GAP * PROP_SLIDE_SCALE * e)

	if k >= 1.0:
		_settle_props(NODE_GAP * PROP_SLIDE_SCALE)
		_advance_phase()


func _advance_phase() -> void:
	_phase += 1
	_t = 0.0
	if _phase == 2 or _phase == 4:
		_capture_prop_motion_base()
	if _phase > 4:
		_finish()


func _finish() -> void:
	set_process(false)
	visible = false
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().current_scene != self:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		play(3, 10)
