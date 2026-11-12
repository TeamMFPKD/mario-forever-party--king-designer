class_name AdventureScenery
extends Control

## 百人团房间的纯色剪影装饰：草与花。
##
## 草：每根叶片是一个 Node2D，基部对齐地面；改 `skew` 让叶尖左右飘（基部不动）。
## 花：整朵绕基部轻微摇摆（rotation），花头里的花瓣组持续旋转，像风扇。
##
## 颜色只有一个：`tint`（带 alpha 的纯色），后排自动更淡，形成层次。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

class Sway:
	var node: Node2D
	var amplitude: float = 0.1
	var speed: float = 1.0
	var phase: float = 0.0


class Spin:
	var node: Node2D
	var speed: float = 0.6


const DEFAULT_TINT: Color = Color(0.10, 0.15, 0.26, 0.30)

## 单一剪影色；后排会用 0.62 倍 alpha
var tint: Color = DEFAULT_TINT
## 随机种子，换一个数字就换一套布局
var seed_value: int = 7

var _grass: Array[Sway] = []
var _flowers: Array[Sway] = []
var _petals: Array[Spin] = []
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
			# 剪切变换：基部固定，叶尖左右摆
			sway.node.skew = sin(_time * sway.speed + sway.phase) * sway.amplitude
	for sway: Sway in _flowers:
		if is_instance_valid(sway.node):
			sway.node.rotation = sin(_time * sway.speed + sway.phase) * sway.amplitude
	for spin: Spin in _petals:
		if is_instance_valid(spin.node):
			spin.node.rotation += delta * spin.speed


func _on_resized() -> void:
	_rebuild.call_deferred()


func _rebuild() -> void:
	if _rebuilding:
		return
	_rebuilding = true
	_clear()
	var width: float = size.x
	var height: float = size.y
	if width < 80.0 or height < 80.0:
		_rebuilding = false
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var ground: float = height + 4.0

	# 最底层：几座很扁的草坡，把孤立的草叶连成一片草地
	_spawn_hills(rng, width, ground, 0.7, 3)
	# 后排：淡、稀、矮
	_spawn_grass(rng, width, ground, 0.62, 9, 30.0, 50.0)
	_spawn_flowers(rng, width, ground, 0.62, 2, 88.0, 110.0)
	# 前排：实、疏（错开位置，避免完全重叠）
	_spawn_grass(rng, width, ground, 1.0, 6, 44.0, 70.0)
	_spawn_flowers(rng, width, ground, 1.0, 3, 112.0, 146.0)

	_apply_tint()
	_rebuilding = false


func _clear() -> void:
	_grass.clear()
	_flowers.clear()
	_petals.clear()
	_shapes.clear()
	_lines.clear()
	var children: Array[Node] = get_children()
	for child: Node in children:
		remove_child(child)
		child.queue_free()


## 很扁的草坡：底边贴地，看起来像连绵的草地轮廓。
func _spawn_hills(
	rng: RandomNumberGenerator,
	width: float,
	ground: float,
	alpha_scale: float,
	count: int
) -> void:
	var hill_width: float = width / float(count) * 1.45
	var index: int = 0
	while index < count:
		var hill: Polygon2D = Polygon2D.new()
		hill.polygon = _ellipse_points(hill_width * 0.5, rng.randf_range(46.0, 68.0), 26)
		hill.position = Vector2((float(index) + 0.5) / float(count) * width, ground)
		hill.set_meta("alpha_scale", alpha_scale)
		add_child(hill)
		_shapes.append(hill)
		index += 1


func _spawn_grass(
	rng: RandomNumberGenerator,
	width: float,
	ground: float,
	alpha_scale: float,
	count: int,
	min_height: float,
	max_height: float
) -> void:
	var index: int = 0
	while index < count:
		var slot: float = (float(index) + rng.randf_range(0.15, 0.85)) / float(count)
		var clump: Node2D = Node2D.new()
		clump.position = Vector2(slot * width, ground)
		add_child(clump)

		var blades: int = rng.randi_range(2, 3)
		var blade_index: int = 0
		while blade_index < blades:
			var blade: Node2D = Node2D.new()
			blade.position = Vector2(rng.randf_range(-13.0, 13.0), 0.0)
			clump.add_child(blade)

			var shape: Polygon2D = Polygon2D.new()
			# 同一丛里的草叶左右交替外弯，形成卡通草簇
			var lean: float = -1.0 if blade_index % 2 == 0 else 1.0
			shape.polygon = _blade_points(rng.randf_range(min_height, max_height), rng.randf_range(16.0, 24.0), lean)
			shape.set_meta("alpha_scale", alpha_scale)
			blade.add_child(shape)
			_shapes.append(shape)

			var sway: Sway = Sway.new()
			sway.node = blade
			sway.amplitude = rng.randf_range(0.10, 0.20)
			sway.speed = rng.randf_range(0.9, 1.7)
			sway.phase = rng.randf_range(0.0, TAU)
			_grass.append(sway)
			blade_index += 1
		index += 1


func _spawn_flowers(
	rng: RandomNumberGenerator,
	width: float,
	ground: float,
	alpha_scale: float,
	count: int,
	min_height: float,
	max_height: float
) -> void:
	var index: int = 0
	while index < count:
		var slot: float = (float(index) + rng.randf_range(0.2, 0.8)) / float(count)
		_make_flower(rng, Vector2(slot * width, ground), rng.randf_range(min_height, max_height), alpha_scale)
		index += 1


func _make_flower(rng: RandomNumberGenerator, base: Vector2, height: float, alpha_scale: float) -> void:
	var flower: Node2D = Node2D.new()
	flower.position = base
	add_child(flower)

	var stem: Line2D = Line2D.new()
	stem.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(5.0, -height * 0.42),
		Vector2(1.0, -height * 0.78),
	])
	stem.width = 8.0
	stem.set_meta("alpha_scale", alpha_scale)
	flower.add_child(stem)
	_lines.append(stem)

	_add_leaf(flower, Vector2(2.0, -height * 0.3), 1.0, alpha_scale)
	_add_leaf(flower, Vector2(4.0, -height * 0.52), -1.0, alpha_scale)

	var head: Node2D = Node2D.new()
	head.position = Vector2(1.0, -height * 0.78)
	flower.add_child(head)

	var spin: Node2D = Node2D.new()
	head.add_child(spin)

	var petal_count: int = rng.randi_range(5, 6)
	var petal_index: int = 0
	while petal_index < petal_count:
		var angle: float = TAU * float(petal_index) / float(petal_count)
		var petal: Polygon2D = Polygon2D.new()
		petal.polygon = _ellipse_points(12.0, 19.0)
		petal.position = Vector2(0.0, -16.0).rotated(angle)
		petal.rotation = angle
		petal.set_meta("alpha_scale", alpha_scale)
		spin.add_child(petal)
		_shapes.append(petal)
		petal_index += 1

	var core: Polygon2D = Polygon2D.new()
	core.polygon = _ellipse_points(11.0, 11.0)
	core.set_meta("alpha_scale", alpha_scale)
	head.add_child(core)
	_shapes.append(core)

	var spin_data: Spin = Spin.new()
	spin_data.node = spin
	spin_data.speed = rng.randf_range(0.45, 0.95) * (1.0 if rng.randf() > 0.5 else -1.0)
	_petals.append(spin_data)

	var sway: Sway = Sway.new()
	sway.node = flower
	sway.amplitude = rng.randf_range(0.05, 0.10)
	sway.speed = rng.randf_range(0.6, 1.1)
	sway.phase = rng.randf_range(0.0, TAU)
	_flowers.append(sway)


func _add_leaf(flower: Node2D, at: Vector2, direction: float, alpha_scale: float) -> void:
	var leaf: Node2D = Node2D.new()
	leaf.position = at
	leaf.rotation = deg_to_rad(-34.0) * direction
	flower.add_child(leaf)

	var shape: Polygon2D = Polygon2D.new()
	shape.polygon = _ellipse_points(10.0, 18.0)
	shape.position = Vector2(16.0 * direction, 0.0)
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
	while index <= segments:
		var t: float = float(index) / float(segments)
		var half: float = width * 0.5 * (1.0 - t) * (1.0 - t * 0.3)
		var center: Vector2 = Vector2(sin(t * 1.15) * width * 0.5 * lean, -height * t)
		points.append(center + Vector2(half, 0.0))
		index += 1
	index = segments
	while index >= 0:
		var t: float = float(index) / float(segments)
		var half: float = width * 0.5 * (1.0 - t) * (1.0 - t * 0.3)
		var center: Vector2 = Vector2(sin(t * 1.15) * width * 0.5 * lean, -height * t)
		points.append(center - Vector2(half, 0.0))
		index -= 1
	return points


func _ellipse_points(rx: float, ry: float, segments: int = 20) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var index: int = 0
	while index < segments:
		var angle: float = TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
		index += 1
	return points
