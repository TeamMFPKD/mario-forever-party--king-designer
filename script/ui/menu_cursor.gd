extends Control
class_name UiMenuCursor

## 菜单聚焦四角光标（**纯表现组件**）。
##
## 它只负责"画"：位置跟随、呼吸、按下变黄。
## 谁被选中、方向键怎么走、确认键触发谁，全部由 autoload `UiNavigator` 决定
## （见 `script/utils/ui_navigator.gd`）。本节点不再自己收集按钮、不再自己读输入。
##
## 三条表现要求：
## 1. 换选中项时位置用极短缓动跟随，不瞬移；
## 2. 常态做"四角靠近中心 → 远离中心"的轻微呼吸（默认 ±2.5%，周期 1.8s）；
## 3. 按下确认键时红色（#E8342A）平滑变成主题黄（#FFC531），松开恢复。

const TINT_SHADER_PATH: String = "res://shader/ui_cursor_tint.gdshader"

## 光标相对目标控件外扩的像素
@export var padding: Vector2 = Vector2(10.0, 8.0)
## 位置跟随的缓动时长（秒）；<= 0 表示瞬移
@export var move_duration: float = 0.14
## 呼吸幅度：四角沿"中心 ↔ 角"方向缩放的百分比
@export var breath_amplitude: float = 0.025
## 呼吸周期（秒）
@export var breath_period: float = 1.8
## 常态色（贴图原始红）
@export var base_color: Color = Color(0.909804, 0.203922, 0.164706, 1.0)
## 按下确认键时的高亮色（主题黄）
@export var highlight_color: Color = Color(1.0, 0.772549, 0.192157, 1.0)
## 红↔黄的过渡速度
@export var highlight_speed: float = 12.0

var _target_rect: Rect2 = Rect2()
var _base_rect: Rect2 = Rect2()
var _has_target: bool = false
var _breath_time: float = 0.0
var _highlight: float = 0.0
var _highlight_target: float = 0.0
var _tint: ShaderMaterial = null

@onready var _corner_tl: TextureRect = $CornerTL
@onready var _corner_tr: TextureRect = $CornerTR
@onready var _corner_bl: TextureRect = $CornerBL
@onready var _corner_br: TextureRect = $CornerBR


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4096
	var corners: Array[TextureRect] = _corners()
	_tint = _build_tint()
	for corner: TextureRect in corners:
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		corner.stretch_mode = TextureRect.STRETCH_KEEP
		if _tint != null:
			corner.material = _tint
	visible = false


func _process(delta: float) -> void:
	if not visible or not _has_target:
		return
	_follow_target(delta)
	_advance_breath(delta)
	_advance_highlight(delta)
	_layout(1.0)


# ---------------------------------------------------------------------------
# 对外 API（由 UiNavigator 调用）
# ---------------------------------------------------------------------------

## 显示光标并朝向 rect（本节点父级的局部坐标）。instant 为 true 时不做跟随缓动。
##
## 每帧被调用时只更新目标矩形，实际摆放交给 _process，避免打断呼吸相位。
func show_at(rect: Rect2, instant: bool = false) -> void:
	_target_rect = rect
	if instant or not _has_target:
		_base_rect = rect
		_has_target = true
		_breath_time = 0.0
		_layout(1.0)
	visible = true


## 隐藏光标。
func hide_cursor() -> void:
	visible = false
	_has_target = false


## 按下确认键时置 true，松开置 false。
func set_highlight(on: bool) -> void:
	_highlight_target = 1.0 if on else 0.0


## 当前光标框（含 padding，本节点父级局部坐标）。
func get_frame_rect() -> Rect2:
	return _base_rect.grow_individual(padding.x, padding.y, padding.x, padding.y)


# ---------------------------------------------------------------------------
# 内部
# ---------------------------------------------------------------------------

func _corners() -> Array[TextureRect]:
	return [_corner_tl, _corner_tr, _corner_bl, _corner_br]


func _build_tint() -> ShaderMaterial:
	var res: Resource = load(TINT_SHADER_PATH)
	if not (res is Shader):
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = res as Shader
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("highlight_color", highlight_color)
	mat.set_shader_parameter("highlight_amount", 0.0)
	return mat


func _follow_target(delta: float) -> void:
	if move_duration <= 0.0:
		_base_rect = _target_rect
		return
	# 指数收敛：约 3.5 个时间常数后到位，起步快、末端缓
	var weight: float = clampf(1.0 - exp(-3.5 * delta / move_duration), 0.0, 1.0)
	# Rect2 没有 lerp()，位置和尺寸分别插值
	_base_rect = Rect2(
		_base_rect.position.lerp(_target_rect.position, weight),
		_base_rect.size.lerp(_target_rect.size, weight)
	)
	# 收敛到亚像素后直接吸附：指数收敛永远差一点点，留着 0.x px 偏差会让描边发虚
	if _base_rect.position.distance_to(_target_rect.position) < 0.5 \
			and _base_rect.size.distance_to(_target_rect.size) < 0.5:
		_base_rect = _target_rect


func _advance_breath(delta: float) -> void:
	_breath_time += delta


func _advance_highlight(delta: float) -> void:
	_highlight = move_toward(_highlight, _highlight_target, maxf(highlight_speed, 0.01) * delta)
	if _tint != null:
		_tint.set_shader_parameter("highlight_amount", _highlight)


## 按呼吸系数摆放四个角。
func _layout(scale_k: float) -> void:
	var frame: Rect2 = get_frame_rect()
	var center: Vector2 = frame.get_center()
	var breath: float = 1.0
	if breath_period > 0.0 and breath_amplitude > 0.0:
		breath = 1.0 + breath_amplitude * sin(_breath_time * TAU / breath_period)
	var k: float = scale_k * breath
	var corners: Array[TextureRect] = _corners()
	for corner: TextureRect in corners:
		var size: Vector2 = _corner_size(corner)
		var anchor: Vector2 = _anchor_of(frame, corner, size)
		corner.position = center + (anchor - center) * k
		corner.size = size


func _corner_size(corner: TextureRect) -> Vector2:
	if corner.texture == null:
		return Vector2(26.0, 26.0)
	return corner.texture.get_size()


func _anchor_of(frame: Rect2, corner: TextureRect, size: Vector2) -> Vector2:
	if corner == _corner_tl:
		return frame.position
	if corner == _corner_tr:
		return Vector2(frame.end.x - size.x, frame.position.y)
	if corner == _corner_bl:
		return Vector2(frame.position.x, frame.end.y - size.y)
	return frame.end - size
