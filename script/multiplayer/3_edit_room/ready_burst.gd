extends Control

## 编辑器“制作完毕！”按钮的爆炸星底板（对应玩家列表 Ready 的星形）。
##
## 不贴图、也不拉伸贴图：按控件当前宽高实时计算星形轮廓，
## 尖刺长度固定为短边的比例、尖刺数量随周长变化，因此任意长宽比都不会被压扁。
## 三层叠画（黑边 / 白圈 / 黄面）共用同一套顶点角度，保证描边均匀。

@export var edge_color: Color = Color(0.06, 0.06, 0.06, 1)
@export var ring_color: Color = Color(1, 1, 1, 1)
@export var fill_color: Color = Color(0.988, 0.796, 0, 1)
## 尖刺长度占控件短边的比例
@export_range(0.04, 0.3, 0.01) var spike_length_ratio: float = 0.16
## 相邻尖刺的弧长间距（像素），越小尖刺越密
@export_range(10.0, 48.0, 1.0) var spike_spacing: float = 22.0
## 白圈与黄面相对黑边的内缩宽度（像素）
@export_range(1.0, 10.0, 0.5) var ring_width: float = 4.0
## 尖刺长度的随机浮动，避免过于机械
@export_range(0.0, 0.3, 0.01) var tip_variation: float = 0.1

const SAMPLE_COUNT: int = 480

## 每个顶点的椭圆角度
var _angles: PackedFloat32Array = PackedFloat32Array()
## 每个顶点的外拉系数：0 = 内圈凹点，>0 = 尖刺顶点（含随机浮动）
var _factors: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_rebuild_layout()

func _on_resized() -> void:
	_rebuild_layout()
	queue_redraw()

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0 or _angles.is_empty():
		return
	_draw_star(0.0, edge_color)
	_draw_star(ring_width, ring_color)
	_draw_star(ring_width * 2.0, fill_color)

func _draw_star(inset: float, color: Color) -> void:
	var points: PackedVector2Array = _build_star(inset)
	if points.size() < 6:
		return
	draw_colored_polygon(points, color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color, 1.5, true)

## 只用最外层（不内缩）的椭圆计算一次顶点角度与尖刺浮动，
## 内层描边复用同一批角度，避免各层尖刺错位。
func _rebuild_layout() -> void:
	_angles = PackedFloat32Array()
	_factors = PackedFloat32Array()
	if size.x < 8.0 or size.y < 8.0:
		return

	var center: Vector2 = size * 0.5
	var tip_rx: float = maxf(center.x, 1.0)
	var tip_ry: float = maxf(center.y, 1.0)
	var spike_length: float = maxf(minf(size.x, size.y) * spike_length_ratio, 2.0)
	var base_rx: float = maxf(tip_rx - spike_length, tip_rx * 0.45)
	var base_ry: float = maxf(tip_ry - spike_length, tip_ry * 0.45)

	var samples: PackedVector2Array = PackedVector2Array()
	var arc_lengths: PackedFloat32Array = PackedFloat32Array()
	var total_length: float = 0.0
	var previous: Vector2 = Vector2.ZERO
	for i: int in range(SAMPLE_COUNT + 1):
		var angle: float = TAU * float(i) / float(SAMPLE_COUNT)
		var point: Vector2 = Vector2(cos(angle) * base_rx, sin(angle) * base_ry)
		if i > 0:
			total_length += previous.distance_to(point)
		samples.append(point)
		arc_lengths.append(total_length)
		previous = point

	if total_length <= 0.001:
		return

	var spike_count: int = clampi(roundi(total_length / maxf(spike_spacing, 4.0)), 6, 60)
	var step: float = total_length / float(spike_count * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261108

	for i: int in range(spike_count * 2):
		var base_point: Vector2 = _sample_ellipse(samples, arc_lengths, step * float(i))
		_angles.append(atan2(base_point.y / base_ry, base_point.x / base_rx))
		if i % 2 == 0:
			_factors.append(1.0 + rng.randf_range(-tip_variation, tip_variation))
		else:
			_factors.append(0.0)

func _build_star(inset: float) -> PackedVector2Array:
	var center: Vector2 = size * 0.5
	var tip_rx: float = maxf(center.x - inset, 1.0)
	var tip_ry: float = maxf(center.y - inset, 1.0)
	var spike_length: float = maxf(minf(size.x, size.y) * spike_length_ratio, 2.0)
	var base_rx: float = maxf(tip_rx - spike_length, tip_rx * 0.45)
	var base_ry: float = maxf(tip_ry - spike_length, tip_ry * 0.45)

	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(_angles.size()):
		var angle: float = _angles[i]
		var factor: float = _factors[i]
		var point: Vector2
		if factor > 0.0:
			point = Vector2(cos(angle) * tip_rx, sin(angle) * tip_ry) * factor
		else:
			point = Vector2(cos(angle) * base_rx, sin(angle) * base_ry)
		points.append(center + point)
	return points

func _sample_ellipse(samples: PackedVector2Array, arc_lengths: PackedFloat32Array, target: float) -> Vector2:
	var last: int = samples.size() - 1
	if target <= 0.0:
		return samples[0]
	if target >= arc_lengths[last]:
		return samples[last]
	var low: int = 0
	var high: int = last
	while low < high - 1:
		var mid: int = (low + high) >> 1
		if arc_lengths[mid] <= target:
			low = mid
		else:
			high = mid
	var segment: float = arc_lengths[high] - arc_lengths[low]
	if segment <= 0.0001:
		return samples[low]
	var weight: float = (target - arc_lengths[low]) / segment
	return samples[low].lerp(samples[high], weight)
