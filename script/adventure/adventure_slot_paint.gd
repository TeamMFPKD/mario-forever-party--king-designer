extends ColorRect

class_name AdventureSlotPaint

## 无尽团存档卡的「彩色油漆桶」卡面（挂在存档卡 Button 下的 Paint 节点）。
##
## 由 adventure_save_slots.gd 按存档的 mode 打开 / 关闭：
##   定量团和空槽保持原来的纯色卡片；无尽团在卡片内部铺一层滚动的多色渐变。
##
## 三个必须由脚本同步给 shader 的量（都不能写死在 .tscn 里）：
##   1. width_px —— 实际像素尺寸。卡片在 HBox 里均分宽度，窗口缩放会变；
##   2. corner_radius_px —— 内缩之后的圆角，必须等于 描边圆角 - 内缩量，
##      否则内圈圆角和外圈描边对不上，四个角会露出白边；
##   3. 明度 / 饱和度 —— 选中态亮一点，未选中压一点。

## 与 Button 描边同宽的内缩量：让卡片自己的 border 仍然可见。
const INSET_PX: float = 6.0
## Button 样式表里的圆角半径（mfmp_theme.tres 的 SBF_btn_normal.corner_radius_*）
const CARD_RADIUS_PX: float = 10.0

const META_SELECTED_VALUE: float = 1.06
const META_IDLE_VALUE: float = 0.94
const META_SELECTED_SATURATION: float = 1.12
const META_IDLE_SATURATION: float = 0.94

var _material: ShaderMaterial = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 场景里的 ShaderMaterial 是 5 张卡共用的同一个资源；每张卡的明度/尺寸不同，
	# 所以这里复制一份，避免改一张带动全部。
	var shared: ShaderMaterial = material as ShaderMaterial
	if shared != null:
		_material = shared.duplicate() as ShaderMaterial
		material = _material
	_sync_size()
	resized.connect(_sync_size)
	item_rect_changed.connect(_sync_size)


## 打开 / 关闭整张卡面。关闭时不隐藏节点以外什么都不做，保持均匀开销。
func set_active(active: bool) -> void:
	visible = active
	if active:
		_sync_size()


func is_active() -> bool:
	return visible


## 选中态只调明度与饱和度：卡面始终是那层彩色油漆，不会因为选中被纯色盖掉。
func set_selected(selected: bool) -> void:
	if _material == null:
		return
	_material.set_shader_parameter(
		"value_mul", META_SELECTED_VALUE if selected else META_IDLE_VALUE
	)
	_material.set_shader_parameter(
		"saturation", META_SELECTED_SATURATION if selected else META_IDLE_SATURATION
	)


## 把当前矩形尺寸写进 shader。HBox 均分宽度后卡片尺寸可能不是整数，取整避免色带抖动。
func _sync_size() -> void:
	if _material == null:
		return
	var size_px: Vector2 = size
	if size_px.x <= 0.0 or size_px.y <= 0.0:
		return
	_material.set_shader_parameter("width_px", size_px.round())
	_material.set_shader_parameter("corner_radius_px", maxf(CARD_RADIUS_PX - INSET_PX, 0.0))


## 探针用：当前写进 shader 的像素尺寸。
func painted_size() -> Vector2:
	if _material == null:
		return Vector2.ZERO
	var value: Variant = _material.get_shader_parameter("width_px")
	if value is Vector2:
		return value
	return Vector2.ZERO