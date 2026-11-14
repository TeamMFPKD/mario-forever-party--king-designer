extends Control

## 百人团舞台的顶栏 / 底栏横幅：橙黄底 + 道具白色剪影 + 内侧锯齿边。
## 视觉与 res://object/ui/adventure_clear_transition.tscn 的黄色过场同源：
## 同一个橙色、同一个 color_filter_replace 白剪影 shader、同一套 sprite/bonus 素材。
##
## 子节点在运行时生成（_ready / resized 按自身尺寸重画），所以场景里只需要一个 Control 占位。
## 锯齿朝横幅内部咬（不额外占外部高度），节点的 size.y 就是橙块本身的最终高度。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 与过关过场一致的橙黄色。
const BANNER_COLOR: Color = Color(1.0, 0.5019608, 0.0, 1.0)
## 锯齿：x 步进与 y 起伏共用同一个 ZIGZAG_STEP —— 每段斜边的斜率恒为 ±1（45°），
## 任何情况下都不做纵向拉伸。齿深也因此恒等于 ZIGZAG_STEP。
const ZIGZAG_STEP: float = 32.0

## 剪影：把素材里的深灰描边统一替换成纯白，其余像素丢弃（参数同过场的 sub_resource）。
const PROP_SHADER: Shader = preload("res://shader/color_filter_replace.gdshader")
const PROP_FILTER_COLOR: Color = Color(0.16078432, 0.16078432, 0.16078432, 1.0)
const PROP_TARGET_COLOR: Color = Color(1, 1, 1, 1)
const PROP_TOLERANCE: float = 0.08

## 四件套素材按顺序：甜菜 / 火之花 / 1UP 蘑菇 / 普通蘑菇；region 取单帧。
const PROP_TEXTURES: Array[Texture2D] = [
	preload("res://sprite/bonus/beetroot.png"),
	preload("res://sprite/bonus/fire_flower.png"),
	preload("res://sprite/bonus/lui.png"),
	preload("res://sprite/bonus/mushroom.png"),
]
const PROP_REGIONS: Array[Rect2] = [
	Rect2(0, 0, 29, 35),
	Rect2(0, 0, 33, 32),
	Rect2(0, 0, 33, 32),
	Rect2(0, 0, 31, 32),
]

## 道具摆位：x = 横幅宽度比例，y = 距横幅顶边的像素，z = 素材下标，w = 缩放。
## 顶栏只沿标题行两侧铺（下方是通栏存档卡，不能压）；底栏铺在动作条中间的空白区。
const TOP_PROPS: Array[Vector4] = [
	Vector4(0.045, 36.0, 2, 1.7),
	Vector4(0.135, 33.0, 3, 1.5),
	Vector4(0.225, 37.0, 1, 1.6),
	Vector4(0.775, 33.0, 0, 1.6),
	Vector4(0.865, 36.0, 3, 1.5),
	Vector4(0.955, 34.0, 2, 1.7),
]
const BOTTOM_PROPS: Array[Vector4] = [
	Vector4(0.360, 84.0, 3, 1.6),
	Vector4(0.500, 80.0, 2, 1.8),
	Vector4(0.640, 86.0, 1, 1.6),
]

## true = 锯齿在底边（顶栏用）；false = 锯齿在顶边（底栏用）。
@export var zigzag_bottom: bool = true

## 白剪影材质所有 Sprite2D 共用一份（参数完全相同）。
static var _shared_material: ShaderMaterial

## 上次绘制用的尺寸：窗口 resize 会连续触发 resized，尺寸没变就跳过重建。
var _built_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()
	resized.connect(_rebuild)


func _rebuild() -> void:
	var banner_size: Vector2 = size
	if banner_size.x < 2.0 or banner_size.y < 2.0:
		return
	if is_equal_approx(banner_size.x, _built_size.x) \
			and is_equal_approx(banner_size.y, _built_size.y):
		return
	_built_size = banner_size
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_add_shape(banner_size.x, banner_size.y)
	_add_props(banner_size.x)


func _add_shape(width: float, height: float) -> void:
	var shape: Polygon2D = Polygon2D.new()
	shape.name = "Shape"
	shape.color = BANNER_COLOR
	shape.polygon = _shape_points(width, height)
	add_child(shape)


## 顶栏：左上 → 右上 → 右下 → 底边锯齿（从右往左）→ 闭合；
## 底栏：左下 → 右下 → 右上 → 顶边锯齿（从右往左）→ 闭合。
## 齿尖落在外沿、齿根咬进 ZIGZAG_STEP，所以锯齿占的是横幅自己的高度。
func _shape_points(width: float, height: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if zigzag_bottom:
		points.append(Vector2(0.0, 0.0))
		points.append(Vector2(width, 0.0))
		points.append(Vector2(width, height))
		_append_zigzag(points, width, height, height - ZIGZAG_STEP)
	else:
		points.append(Vector2(0.0, height))
		points.append(Vector2(width, height))
		points.append(Vector2(width, 0.0))
		_append_zigzag(points, width, 0.0, ZIGZAG_STEP)
	return points


## 沿水平边从右往左铺齿。x 步进与 y 起伏始终相等，所以每段斜边都是 ±45°；
## 宽度不是 ZIGZAG_STEP 整数倍时，最后一段沿 45° 截断（不会拉成缓坡）。
func _append_zigzag(
	points: PackedVector2Array, width: float, tip_y: float, root_y: float
) -> void:
	var x: float = width
	var y: float = tip_y
	var to_root: bool = true
	while x > 0.01:
		var dx: float = minf(ZIGZAG_STEP, x)
		var target_y: float = root_y if to_root else tip_y
		var dy: float = target_y - y
		if absf(dy) > dx:
			# 最后一段走不满整个齿高：按 ±45° 收到边界上。
			dy = signf(dy) * dx
		y += dy
		x -= dx
		points.append(Vector2(x, y))
		to_root = not to_root


func _add_props(width: float) -> void:
	var layout: Array[Vector4] = TOP_PROPS if zigzag_bottom else BOTTOM_PROPS
	for item: Vector4 in layout:
		var index: int = int(item.z)
		if index < 0 or index >= PROP_TEXTURES.size():
			continue
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Prop%d" % index
		sprite.texture = PROP_TEXTURES[index]
		sprite.region_enabled = true
		sprite.region_rect = PROP_REGIONS[index]
		sprite.scale = Vector2(item.w, item.w)
		sprite.position = Vector2(item.x * width, item.y)
		sprite.material = _prop_material()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)


func _prop_material() -> ShaderMaterial:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = PROP_SHADER
		_shared_material.set_shader_parameter("filter_color", PROP_FILTER_COLOR)
		_shared_material.set_shader_parameter("target_color", PROP_TARGET_COLOR)
		_shared_material.set_shader_parameter("tolerance", PROP_TOLERANCE)
		_shared_material.set_shader_parameter("keep_alpha", true)
	return _shared_material
