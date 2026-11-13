class_name AdventureScenery
extends Control

## 迷你纯色剪影装饰：草簇 / 小花，单件尺寸取 32 / 64 / 96，随机撒在容器里。
## 用来点缀关卡椭圆附近，不铺满背景。
##
## 草：一整片矮胖的连续尖峰剪影（轮廓就是一串 ^^^^^，峰尖倒圆角），
##     改 `skew` 让峰尖左右飘（基部不动）。
## 花：粗短茎 + 圆叶 + 大花头，矮胖卡通比例，整朵绕基部轻微摇摆。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

class Sway:
	var node: Node2D
	var amplitude: float = 0.1
	var speed: float = 1.0
	var phase: float = 0.0


const DEFAULT_TINT: Color = Color(0.10, 0.15, 0.26, 0.30)
const SIZES: Array[float] = [32.0, 64.0, 96.0]

## 单一剪影色；换主题时改它会立刻给已生成的剪影重新上色。
var tint: Color = DEFAULT_TINT:
	set(value):
		tint = value
		_apply_tint()
## 随机种子：换数字换一套摆位
var seed_value: int = 7
## 密度倍率，1.0 大约每 42000 平方像素一件
var density: float = 1.0

var _grass: Array[Sway] = []
var _flowers: Array[Sway] = []
var _shapes: Array[Polygon2D] = []
var _lines: Array[Line2D] = []
var _time: float = 0.0
var _rebuilding: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	_rebuild.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	for sway: Sway in _grass:
		if is_instance_valid(sway.node):
			# 剪切变换：基部固定，峰尖左右摆
			sway.node.skew = sin(_time * sway.speed + sway.phase) * sway.amplitude
	for sway: Sway in _flowers:
		if is_instance_valid(sway.node):
			sway.node.rotation = sin(_time * sway.speed + sway.phase) * sway.amplitude


func _on_resized() -> void:
	_rebuild.call_deferred()


func _rebuild() -> void:
	if _rebuilding:
		return
	_rebuilding = true
	_clear()

	var width: float = size.x
	var height: float = size.y
	if width < 120.0 or height < 120.0:
		_rebuilding = false
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	var target_count: int = clampi(int(width * height / 36000.0 * density), 6, 22)
	var index: int = 0
	while index < target_count:
		var item_size: float = SIZES[rng.randi_range(0, SIZES.size() - 1)]
		# 只摆在关卡椭圆的上下两侧，贴着那一排，而不是铺满整块面板
		var base_y: float = rng.randf_range(height * 0.1, height * 0.34)
		if rng.randf() < 0.55:
			base_y = rng.randf_range(height * 0.66, height * 0.94)
		var base: Vector2 = Vector2(
			rng.randf_range(40.0 + item_size * 0.82, width - 40.0 - item_size * 0.82),
			base_y
		)
		var alpha_scale: float = rng.randf_range(0.72, 1.0)
		if rng.randf() < 0.55:
			_make_grass(rng, base, item_size, alpha_scale)
		else:
			_make_flower(rng, base, item_size, alpha_scale)
		index += 1

	_apply_tint()
	_rebuilding = false


func _clear() -> void:
	_grass.clear()
	_flowers.clear()
	_shapes.clear()
	_lines.clear()
	var children: Array[Node] = get_children()
	for child: Node in children:
		remove_child(child)
		child.queue_free()


## 一簇草：底边贴地、上缘是一串尖峰的连续剪影，整体随风轻摆。
func _make_grass(rng: RandomNumberGenerator, base: Vector2, size_px: float, alpha_scale: float) -> void:
	var clump: Node2D = Node2D.new()
	clump.position = base
	add_child(clump)

	var shape: Polygon2D = Polygon2D.new()
	shape.polygon = _grass_points(rng, size_px)
	shape.set_meta("alpha_scale", alpha_scale)
	clump.add_child(shape)
	_shapes.append(shape)

	var sway: Sway = Sway.new()
	sway.node = clump
	sway.amplitude = rng.randf_range(0.035, 0.07)
	sway.speed = rng.randf_range(0.8, 1.5)
	sway.phase = rng.randf_range(0.0, TAU)
	_grass.append(sway)


## 草簇轮廓：矮胖的连续尖峰（^^^^^），峰尖与谷底都倒圆角，卡通剪影。
func _grass_points(rng: RandomNumberGenerator, size_px: float) -> PackedVector2Array:
	var width: float = size_px * rng.randf_range(1.05, 1.35)
	var height: float = size_px * rng.randf_range(0.42, 0.56)
	var peaks: int = rng.randi_range(3, 5)
	var pitch: float = width / float(peaks)

	var cycle: PackedVector2Array = PackedVector2Array()
	cycle.append(Vector2(-width * 0.5, 0.0))
	cycle.append(Vector2(width * 0.5, 0.0))
	cycle.append(Vector2(width * 0.5, -height * rng.randf_range(0.16, 0.26)))

	# 从右往左折返：尖峰 → 谷底 → 尖峰……
	var index: int = peaks - 1
	while index >= 0:
		var left: float = -width * 0.5 + pitch * float(index)
		var right: float = left + pitch
		# 峰高随机、两端略矮，峰尖略偏向一侧，避免等距三角形的机械感
		var peak_height: float = height * rng.randf_range(0.68, 1.0)
		if index == 0 or index == peaks - 1:
			peak_height *= 0.86
		cycle.append(Vector2(lerpf(left, right, rng.randf_range(0.36, 0.64)), -peak_height))
		if index > 0:
			cycle.append(Vector2(left, -height * rng.randf_range(0.16, 0.28)))
		index -= 1
	cycle.append(Vector2(-width * 0.5, -height * rng.randf_range(0.16, 0.26)))
	return _round_polygon(cycle, 0.2, 4, true)


## 一朵小花：粗短茎 + 圆叶 + 大花头，整体高度约 0.7 × size_px，矮胖卡通比例。
func _make_flower(rng: RandomNumberGenerator, base: Vector2, size_px: float, alpha_scale: float) -> void:
	var flower: Node2D = Node2D.new()
	flower.position = base
	add_child(flower)

	var stem: Line2D = Line2D.new()
	stem.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(size_px * 0.03, -size_px * 0.2),
		Vector2(0.0, -size_px * 0.38),
	])
	stem.width = maxf(2.0, size_px * 0.075)
	stem.begin_cap_mode = Line2D.LINE_CAP_ROUND
	stem.end_cap_mode = Line2D.LINE_CAP_ROUND
	stem.set_meta("alpha_scale", alpha_scale)
	flower.add_child(stem)
	_lines.append(stem)

	_add_leaf(flower, Vector2(size_px * 0.02, -size_px * 0.15), 1.0, size_px, alpha_scale)

	var head: Polygon2D = Polygon2D.new()
	head.polygon = _round_polygon(_flower_head_points(size_px * 0.28, rng.randi_range(5, 6)), 0.26, 3)
	head.position = Vector2(0.0, -size_px * 0.42)
	head.set_meta("alpha_scale", alpha_scale)
	flower.add_child(head)
	_shapes.append(head)

	var sway: Sway = Sway.new()
	sway.node = flower
	sway.amplitude = rng.randf_range(0.05, 0.09)
	sway.speed = rng.randf_range(0.6, 1.1)
	sway.phase = rng.randf_range(0.0, TAU)
	_flowers.append(sway)


## 尖瓣花头：每片花瓣由「瓣间凹点 → 两侧 → 尖顶」连成，外轮廓呈尖角星形。
func _flower_head_points(radius: float, petals: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var step: float = TAU / float(petals)
	var index: int = 0
	while index < petals:
		var angle: float = step * float(index)
		points.append(Vector2(cos(angle - step * 0.5), sin(angle - step * 0.5)) * radius * 0.42)
		points.append(Vector2(cos(angle - step * 0.22), sin(angle - step * 0.22)) * radius * 0.82)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
		points.append(Vector2(cos(angle + step * 0.22), sin(angle + step * 0.22)) * radius * 0.82)
		index += 1
	return points


## 把闭合轮廓的每个转折点倒成圆角（二次贝塞尔），得到圆润的卡通边。
## keep_flat = true 时跳过贴地角（y ≈ 0），保证草簇底边仍然平直。
func _round_polygon(points: PackedVector2Array, radius_scale: float, segments: int = 4, keep_flat: bool = false) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var count: int = points.size()
	var index: int = 0
	while index < count:
		var previous: Vector2 = points[(index - 1 + count) % count]
		var current: Vector2 = points[index]
		var next: Vector2 = points[(index + 1) % count]
		if keep_flat and current.y >= -0.01:
			result.append(current)
			index += 1
			continue
		var to_previous: Vector2 = previous - current
		var to_next: Vector2 = next - current
		var trim: float = minf(to_previous.length(), to_next.length()) * radius_scale
		if trim < 0.5:
			result.append(current)
			index += 1
			continue
		var entry: Vector2 = current + to_previous.normalized() * trim
		var exit: Vector2 = current + to_next.normalized() * trim
		var step: int = 0
		while step <= segments:
			var t: float = float(step) / float(segments)
			var inverse: float = 1.0 - t
			result.append(entry * inverse * inverse + current * 2.0 * inverse * t + exit * t * t)
			step += 1
		index += 1
	return result


func _add_leaf(flower: Node2D, at: Vector2, direction: float, size_px: float, alpha_scale: float) -> void:
	var leaf: Node2D = Node2D.new()
	leaf.position = at
	leaf.rotation = deg_to_rad(40.0) * direction
	flower.add_child(leaf)

	var shape: Polygon2D = Polygon2D.new()
	shape.polygon = _blade_points(size_px * 0.24, size_px * 0.16, direction)
	shape.set_meta("alpha_scale", alpha_scale)
	leaf.add_child(shape)
	_shapes.append(shape)


func _apply_tint() -> void:
	for shape: Polygon2D in _shapes:
		var alpha_scale: float = float(shape.get_meta("alpha_scale", 1.0))
		shape.color = Color(tint.r, tint.g, tint.b, tint.a * alpha_scale)
	for line: Line2D in _lines:
		var alpha_scale: float = float(line.get_meta("alpha_scale", 1.0))
		line.default_color = Color(tint.r, tint.g, tint.b, tint.a * alpha_scale)


## 卡通叶片：粗基部 + 平滑外弯，尖端收尖；lean 决定往左还是往右弯。
func _blade_points(height: float, width: float, lean: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 9
	var index: int = 0
	var tip: float = width * 0.06
	while index <= segments:
		var t: float = float(index) / float(segments)
		var half: float = lerpf(width * 0.5, tip, t) * (1.0 - t * 0.25)
		var center: Vector2 = Vector2(sin(t * 1.15) * width * 0.5 * lean, -height * t)
		points.append(center + Vector2(half, 0.0))
		index += 1
	index = segments
	while index >= 0:
		var t: float = float(index) / float(segments)
		var half: float = lerpf(width * 0.5, tip, t) * (1.0 - t * 0.25)
		var center: Vector2 = Vector2(sin(t * 1.15) * width * 0.5 * lean, -height * t)
		points.append(center - Vector2(half, 0.0))
		index -= 1
	return points
