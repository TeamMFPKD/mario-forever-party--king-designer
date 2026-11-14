class_name AdventureSceneryStyles
extends RefCounted

## 百人团装饰的卡通风剪影形状候选库（第二版）。
## 首轮未选中的 B/C/D/E 已删除；保留 A/F/G/H 四套（现编号 01~04），
## 另加 16 套自然 / 非自然景物。每个风格提供「主形 + 配形」两个剪影，
## 返回 Node2D，原点在基部（y=0 为地面）。一律单色剪影，不着色、不描边。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const NAMES: Array[String] = [
	"01 圆团子", "02 像素块", "03 双叶芽", "04 波浪草带",
	"05 云朵", "06 山峦", "07 松树", "08 蘑菇",
	"09 仙人掌", "10 月亮星", "11 贝壳", "12 小鸟",
	"13 石堆", "14 小屋", "15 齿轮", "16 灯泡",
	"17 礼物盒", "18 皇冠", "19 火箭", "20 音符",
]
const PRIMARY_DESC: Array[String] = [
	"四个半圆连成一整片", "直角阶梯方块锯齿", "对生双叶 + 顶芽", "连续 S 形波浪长条",
	"大小圆鼓的卡通云", "三座尖峰的山脉", "三层三角松树", "半圆伞盖蘑菇",
	"圆头双臂仙人掌", "弯月牙", "波浪扇贝壳", "海鸥式展翅折线",
	"三块叠石", "三角屋顶小屋", "十齿齿轮", "圆泡灯泡",
	"方盒 + 蝴蝶结", "五尖皇冠", "尖头火箭", "八分音符",
]
const SECONDARY_DESC: Array[String] = [
	"五圆瓣小花", "方块十字花", "侧视牵牛花喇叭", "下垂波浪钟形花",
	"三滴雨", "太阳 + 矮丘", "松果", "两朵小蘑菇",
	"两块卵石", "三颗小星", "五角海星", "带叶小树枝",
	"卵石 + 草簇", "圆冠小树", "圆头螺丝", "放射光芒",
	"系绳气球", "菱形宝石", "小行星", "双音符横梁",
]


static func style_count() -> int:
	return NAMES.size()


static func build_primary(style: int, size: float, color: Color) -> Node2D:
	var root: Node2D = Node2D.new()
	match style:
		0: _p_round(root, size, color)
		1: _p_pixel(root, size, color)
		2: _p_sprout(root, size, color)
		3: _p_wave(root, size, color)
		4: _p_cloud(root, size, color)
		5: _p_mountain(root, size, color)
		6: _p_pine(root, size, color)
		7: _p_mushroom(root, size, color)
		8: _p_cactus(root, size, color)
		9: _p_moon(root, size, color)
		10: _p_shell(root, size, color)
		11: _p_bird(root, size, color)
		12: _p_stones(root, size, color)
		13: _p_house(root, size, color)
		14: _p_gear(root, size, color)
		15: _p_bulb(root, size, color)
		16: _p_gift(root, size, color)
		17: _p_crown(root, size, color)
		18: _p_rocket(root, size, color)
		19: _p_note(root, size, color)
	return root


static func build_secondary(style: int, size: float, color: Color) -> Node2D:
	var root: Node2D = Node2D.new()
	match style:
		0: _s_round_flower(root, size, color)
		1: _s_pixel_flower(root, size, color)
		2: _s_trumpet(root, size, color)
		3: _s_bell(root, size, color)
		4: _s_rain(root, size, color)
		5: _s_sun(root, size, color)
		6: _s_cone(root, size, color)
		7: _s_mini_mushrooms(root, size, color)
		8: _s_pebbles(root, size, color)
		9: _s_stars(root, size, color)
		10: _s_seastar(root, size, color)
		11: _s_branch(root, size, color)
		12: _s_pebble_grass(root, size, color)
		13: _s_tree(root, size, color)
		14: _s_screw(root, size, color)
		15: _s_rays(root, size, color)
		16: _s_balloon(root, size, color)
		17: _s_gem(root, size, color)
		18: _s_planet(root, size, color)
		19: _s_double_note(root, size, color)
	return root


# ── 通用绘制小工具 ────────────────────────────────────────────────

static func _poly(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
	var shape: Polygon2D = Polygon2D.new()
	shape.polygon = points
	shape.color = color
	parent.add_child(shape)


static func _line(parent: Node2D, points: PackedVector2Array, width: float, color: Color) -> void:
	var line: Line2D = Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(line)


static func _disk(cx: float, cy: float, rx: float, ry: float, steps: int = 20) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var index: int = 0
	while index < steps:
		var angle: float = TAU * float(index) / float(steps)
		points.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
		index += 1
	return points


static func _rect_points(cx: float, cy: float, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(cx - width * 0.5, cy - height * 0.5),
		Vector2(cx + width * 0.5, cy - height * 0.5),
		Vector2(cx + width * 0.5, cy + height * 0.5),
		Vector2(cx - width * 0.5, cy + height * 0.5),
	])


## 上半椭圆弧：从右端点走到左端点（y 向上为负）。
static func _arc_up(cx: float, base_y: float, rx: float, ry: float, steps: int = 14) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var index: int = 0
	while index <= steps:
		var t: float = PI * float(index) / float(steps)
		points.append(Vector2(cx + cos(t) * rx, base_y - sin(t) * ry))
		index += 1
	return points


## 水滴叶：基部 (0,0) → 尖端 (0,-length)，lean 让叶身向一侧弯。
static func _teardrop(length: float, width: float, lean: float, steps: int = 12) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var index: int = 0
	while index <= steps:
		var t: float = float(index) / float(steps)
		var half: float = width * 0.5 * pow(sin(PI * t), 0.8) * (1.0 - 0.25 * t)
		var center: float = lean * width * 0.6 * t * t
		points.append(Vector2(center + half, -length * t))
		index += 1
	index = steps - 1
	while index > 0:
		var t: float = float(index) / float(steps)
		var half: float = width * 0.5 * pow(sin(PI * t), 0.8) * (1.0 - 0.25 * t)
		var center: float = lean * width * 0.6 * t * t
		points.append(Vector2(center - half, -length * t))
		index -= 1
	return points


## 圆润花瓣头（极坐标起伏）。
static func _wave_head(radius: float, petals: int, inner: float, steps: int = 72) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var index: int = 0
	while index < steps:
		var angle: float = TAU * float(index) / float(steps)
		var r: float = radius * (inner + (1.0 - inner) * 0.5 * (1.0 + cos(float(petals) * angle)))
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
		index += 1
	return points


## 五角星 / 海星等尖角轮廓。
static func _star_points(radius: float, tips: int = 5, inner: float = 0.45, steps: int = 2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var step: float = TAU / float(tips * steps)
	var index: int = 0
	while index < tips * steps:
		var angle: float = step * float(index) - PI * 0.5
		var r: float = radius if index % steps == 0 else radius * inner
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
		index += 1
	return points


## 弯月牙：外圆左半弧 + 内圆（圆心右移）左半弧，两弧在右侧尖端相接。
static func _crescent(radius: float, steps: int = 24) -> PackedVector2Array:
	var offset: float = radius * 0.5
	var inner: float = radius * 0.9
	var theta: float = acos((radius * radius + offset * offset - inner * inner) / (2.0 * radius * offset))
	var phi: float = atan2(radius * sin(theta), radius * cos(theta) - offset)
	var points: PackedVector2Array = PackedVector2Array()
	var index: int = 0
	while index <= steps:
		var angle: float = theta + (TAU - 2.0 * theta) * float(index) / float(steps)
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
		index += 1
	index = 1
	while index < steps:
		var angle: float = -phi - (TAU - 2.0 * phi) * float(index) / float(steps)
		points.append(Vector2(offset + cos(angle) * inner, sin(angle) * inner))
		index += 1
	return points


## 下圆上尖的雨滴：右侧斜边 → 底部半圆 → 左侧斜边，闭合不自交。
static func _raindrop(height: float, width: float, steps: int = 10) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var index: int = 0
	while index <= steps:
		var t: float = float(index) / float(steps)
		points.append(Vector2(width * 0.5 * pow(t, 0.7), -height + height * 0.62 * t))
		index += 1
	index = 1
	while index <= steps:
		var angle: float = PI * float(index) / float(steps)
		points.append(Vector2(cos(angle) * width * 0.5, -height * 0.38 + sin(angle) * height * 0.38))
		index += 1
	index = steps - 1
	while index >= 1:
		var t: float = float(index) / float(steps)
		points.append(Vector2(-width * 0.5 * pow(t, 0.7), -height + height * 0.62 * t))
		index -= 1
	return points


## 蘑菇单轮廓：半圆伞盖 + 短柄。
static func _mushroom_points(s: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-s * 0.42, -s * 0.36),
		Vector2(-s * 0.12, -s * 0.36),
		Vector2(-s * 0.12, 0.0),
		Vector2(s * 0.12, 0.0),
		Vector2(s * 0.12, -s * 0.36),
		Vector2(s * 0.42, -s * 0.36),
	])
	points.append_array(_arc_up(0.0, -s * 0.36, s * 0.42, s * 0.36))
	return points


## 齿轮轮廓：齿顶 / 齿根交替。
static func _gear_points(radius: float, teeth: int = 10, inner: float = 0.78) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var step: float = TAU / float(teeth * 4)
	var index: int = 0
	while index < teeth * 4:
		var phase: int = index % 4
		var r: float = radius if phase == 1 or phase == 2 else radius * inner
		var angle: float = step * float(index)
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
		index += 1
	return points


static func _stem(parent: Node2D, size: float, color: Color, top: float, width_ratio: float) -> void:
	_line(parent, PackedVector2Array([
		Vector2.ZERO,
		Vector2(size * 0.03, -top * 0.5),
		Vector2(0.0, -top),
	]), maxf(2.0, size * width_ratio), color)


static func _round_leaf(parent: Node2D, size: float, color: Color, at: Vector2, angle_deg: float, length: float) -> void:
	var leaf: Node2D = Node2D.new()
	leaf.position = at
	leaf.rotation = deg_to_rad(angle_deg)
	_poly(leaf, _teardrop(size * length, size * length * 0.62, 0.0), color)
	parent.add_child(leaf)


# ── 保留的四套（原 A / F / G / H）─────────────────────────────────

static func _p_round(parent: Node2D, s: float, color: Color) -> void:
	var width: float = s * 1.3
	var height: float = s * 0.6
	var count: int = 4
	var pitch: float = width / float(count)
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-width * 0.5, 0.0))
	points.append(Vector2(width * 0.5, 0.0))
	var index: int = count - 1
	while index >= 0:
		var cx: float = -width * 0.5 + pitch * (float(index) + 0.5)
		var ry: float = height * (0.7 if index == 0 or index == count - 1 else 1.0)
		points.append_array(_arc_up(cx, -height * 0.12, pitch * 0.5, ry))
		index -= 1
	_poly(parent, points, color)


static func _s_round_flower(parent: Node2D, s: float, color: Color) -> void:
	_stem(parent, s, color, s * 0.5, 0.08)
	_round_leaf(parent, s, color, Vector2(s * 0.02, -s * 0.2), 52.0, 0.3)
	var head: Node2D = Node2D.new()
	head.position = Vector2(0.0, -s * 0.56)
	_poly(head, _wave_head(s * 0.26, 5, 0.7), color)
	parent.add_child(head)


static func _p_pixel(parent: Node2D, s: float, color: Color) -> void:
	var width: float = s * 1.3
	var height: float = s * 0.55
	var count: int = 4
	var pitch: float = width / float(count)
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-width * 0.5, 0.0))
	points.append(Vector2(width * 0.5, 0.0))
	var index: int = count - 1
	while index >= 0:
		var left: float = -width * 0.5 + pitch * float(index)
		var right: float = left + pitch
		var top: float = -height * (0.6 + 0.4 * sin(PI * (float(index) + 0.5) / float(count)))
		points.append(Vector2(right - pitch * 0.12, -height * 0.16))
		points.append(Vector2(right - pitch * 0.12, top))
		points.append(Vector2(left + pitch * 0.12, top))
		points.append(Vector2(left + pitch * 0.12, -height * 0.16))
		points.append(Vector2(left, -height * 0.16))
		index -= 1
	_poly(parent, points, color)


static func _s_pixel_flower(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _rect_points(0.0, -s * 0.28, s * 0.11, s * 0.56), color)
	var head: Vector2 = Vector2(0.0, -s * 0.6)
	var cell: float = s * 0.14
	var dx: int = -1
	while dx <= 1:
		var dy: int = -1
		while dy <= 1:
			if dx != 0 or dy != 0:
				_poly(parent, _rect_points(head.x + float(dx) * cell, head.y + float(dy) * cell, cell * 0.9, cell * 0.9), color)
			dy += 1
		dx += 1
	_poly(parent, _rect_points(head.x, head.y, cell, cell), color)


static func _p_sprout(parent: Node2D, s: float, color: Color) -> void:
	_line(parent, PackedVector2Array([Vector2.ZERO, Vector2(0.0, -s * 0.56)]), maxf(3.0, s * 0.09), color)
	_round_leaf(parent, s, color, Vector2(0.0, -s * 0.28), -58.0, 0.36)
	_round_leaf(parent, s, color, Vector2(0.0, -s * 0.38), 58.0, 0.36)
	_poly(parent, _disk(0.0, -s * 0.58, s * 0.09, s * 0.09), color)


static func _s_trumpet(parent: Node2D, s: float, color: Color) -> void:
	_stem(parent, s, color, s * 0.46, 0.06)
	_round_leaf(parent, s, color, Vector2(s * 0.01, -s * 0.16), -58.0, 0.28)
	_poly(parent, PackedVector2Array([
		Vector2(-s * 0.02, -s * 0.48),
		Vector2(s * 0.08, -s * 0.66),
		Vector2(s * 0.26, -s * 0.82),
		Vector2(s * 0.36, -s * 0.76),
		Vector2(s * 0.34, -s * 0.6),
		Vector2(s * 0.3, -s * 0.48),
		Vector2(s * 0.16, -s * 0.42),
		Vector2(s * 0.04, -s * 0.44),
	]), color)


static func _p_wave(parent: Node2D, s: float, color: Color) -> void:
	var width: float = s * 1.5
	var height: float = s * 0.52
	var steps: int = 48
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-width * 0.5, 0.0))
	points.append(Vector2(width * 0.5, 0.0))
	var index: int = steps
	while index >= 0:
		var t: float = float(index) / float(steps)
		var wave: float = sin(t * TAU * 2.5)
		points.append(Vector2(-width * 0.5 + width * t, -height * (0.35 + 0.45 * (0.5 + 0.5 * wave))))
		index -= 1
	_poly(parent, points, color)


static func _s_bell(parent: Node2D, s: float, color: Color) -> void:
	_stem(parent, s, color, s * 0.76, 0.05)
	_poly(parent, PackedVector2Array([
		Vector2(-s * 0.07, -s * 0.78),
		Vector2(s * 0.07, -s * 0.78),
		Vector2(s * 0.13, -s * 0.64),
		Vector2(s * 0.26, -s * 0.46),
		Vector2(s * 0.17, -s * 0.4),
		Vector2(s * 0.09, -s * 0.46),
		Vector2(0.0, -s * 0.4),
		Vector2(-s * 0.09, -s * 0.46),
		Vector2(-s * 0.17, -s * 0.4),
		Vector2(-s * 0.26, -s * 0.46),
		Vector2(-s * 0.13, -s * 0.64),
	]), color)


# ── 自然景物 ──────────────────────────────────────────────────────

## 05 云朵：中间大圆鼓、两侧小圆鼓，底边内收。
static func _p_cloud(parent: Node2D, s: float, color: Color) -> void:
	var width: float = s * 1.4
	var height: float = s * 0.66
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-width * 0.44, 0.0))
	points.append(Vector2(width * 0.44, 0.0))
	points.append_array(_arc_up(width * 0.3, -height * 0.08, width * 0.22, height * 0.56))
	points.append_array(_arc_up(0.0, -height * 0.08, width * 0.3, height))
	points.append_array(_arc_up(-width * 0.3, -height * 0.08, width * 0.22, height * 0.56))
	_poly(parent, points, color)


static func _s_rain(parent: Node2D, s: float, color: Color) -> void:
	var offsets: Array[float] = [-0.3, 0.0, 0.3]
	var heights: Array[float] = [0.42, 0.6, 0.36]
	var index: int = 0
	while index < offsets.size():
		var drop: Node2D = Node2D.new()
		drop.position = Vector2(s * offsets[index], -s * heights[index])
		drop.rotation = deg_to_rad(12.0)
		_poly(drop, _raindrop(s * 0.3, s * 0.18), color)
		parent.add_child(drop)
		index += 1
	_line(parent, PackedVector2Array([
		Vector2(-s * 0.42, -s * 0.04), Vector2(-s * 0.14, 0.0), Vector2(s * 0.14, -s * 0.04), Vector2(s * 0.42, 0.0),
	]), maxf(2.0, s * 0.035), color)


## 06 山峦：三座不对称尖峰。
static func _p_mountain(parent: Node2D, s: float, color: Color) -> void:
	var width: float = s * 1.45
	var height: float = s * 0.72
	_poly(parent, PackedVector2Array([
		Vector2(-width * 0.5, 0.0),
		Vector2(width * 0.5, 0.0),
		Vector2(width * 0.3, -height * 0.42),
		Vector2(width * 0.12, -height * 0.82),
		Vector2(-width * 0.02, -height * 0.48),
		Vector2(-width * 0.18, -height),
		Vector2(-width * 0.36, -height * 0.45),
	]), color)


static func _s_sun(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(0.0, -s * 0.56, s * 0.2, s * 0.2), color)
	var index: int = 0
	while index < 8:
		var angle: float = TAU * float(index) / 8.0
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var center: Vector2 = Vector2(0.0, -s * 0.56)
		_line(parent, PackedVector2Array([
			center + direction * s * 0.26, center + direction * s * 0.36,
		]), maxf(2.0, s * 0.035), color)
		index += 1
	_poly(parent, PackedVector2Array([
		Vector2(-s * 0.44, 0.0), Vector2(s * 0.44, 0.0), Vector2(s * 0.18, -s * 0.2), Vector2(-s * 0.06, -s * 0.12),
	]), color)


## 07 松树：三层三角 + 树干。
static func _p_pine(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _rect_points(0.0, -s * 0.08, s * 0.14, s * 0.16), color)
	var layers: Array[float] = [0.34, 0.48, 0.62]
	var tops: Array[float] = [0.84, 0.68, 0.52]
	var index: int = 0
	while index < layers.size():
		var half: float = s * layers[index]
		var top: float = -s * tops[index]
		var bottom: float = -s * (tops[index] - 0.26)
		_poly(parent, PackedVector2Array([
			Vector2(0.0, top), Vector2(half, bottom), Vector2(-half, bottom),
		]), color)
		index += 1


static func _s_cone(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(0.0, -s * 0.34, s * 0.19, s * 0.3, 22), color)
	var index: int = 0
	while index < 3:
		var y: float = -s * (0.2 + float(index) * 0.12)
		_line(parent, PackedVector2Array([
			Vector2(-s * 0.16, y), Vector2(s * 0.16, y - s * 0.06),
		]), maxf(2.0, s * 0.035), color)
		index += 1
	_line(parent, PackedVector2Array([Vector2.ZERO, Vector2(0.0, -s * 0.08)]), maxf(2.0, s * 0.06), color)


## 08 蘑菇。
static func _p_mushroom(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _mushroom_points(s), color)


static func _s_mini_mushrooms(parent: Node2D, s: float, color: Color) -> void:
	var left: Node2D = Node2D.new()
	left.position = Vector2(-s * 0.24, 0.0)
	left.scale = Vector2(0.66, 0.66)
	_poly(left, _mushroom_points(s), color)
	parent.add_child(left)
	var right: Node2D = Node2D.new()
	right.position = Vector2(s * 0.24, 0.0)
	right.scale = Vector2(0.48, 0.48)
	_poly(right, _mushroom_points(s), color)
	parent.add_child(right)


## 09 仙人掌：粗圆头主干 + 双臂。
static func _p_cactus(parent: Node2D, s: float, color: Color) -> void:
	_line(parent, PackedVector2Array([Vector2.ZERO, Vector2(0.0, -s * 0.72)]), s * 0.22, color)
	_line(parent, PackedVector2Array([
		Vector2(0.0, -s * 0.42), Vector2(-s * 0.24, -s * 0.42), Vector2(-s * 0.24, -s * 0.56),
	]), s * 0.14, color)
	_line(parent, PackedVector2Array([
		Vector2(0.0, -s * 0.32), Vector2(s * 0.26, -s * 0.32), Vector2(s * 0.26, -s * 0.5),
	]), s * 0.14, color)


static func _s_pebbles(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(-s * 0.2, -s * 0.1, s * 0.24, s * 0.12, 18), color)
	_poly(parent, _disk(s * 0.22, -s * 0.08, s * 0.18, s * 0.09, 18), color)
	_poly(parent, _disk(s * 0.04, -s * 0.05, s * 0.09, s * 0.05, 12), color)


## 10 月亮星：弯月牙。
static func _p_moon(parent: Node2D, s: float, color: Color) -> void:
	var moon: Node2D = Node2D.new()
	moon.position = Vector2(0.0, -s * 0.5)
	moon.rotation = deg_to_rad(-18.0)
	_poly(moon, _crescent(s * 0.44), color)
	parent.add_child(moon)


static func _s_stars(parent: Node2D, s: float, color: Color) -> void:
	var places: Array[Vector2] = [
		Vector2(-s * 0.3, -s * 0.28), Vector2(s * 0.26, -s * 0.5), Vector2(s * 0.06, -s * 0.16),
	]
	var sizes: Array[float] = [0.16, 0.22, 0.11]
	var index: int = 0
	while index < places.size():
		var star: Node2D = Node2D.new()
		star.position = places[index]
		_poly(star, _star_points(s * sizes[index]), color)
		parent.add_child(star)
		index += 1


## 11 贝壳：扇贝波浪边 + 壳纹。
static func _p_shell(parent: Node2D, s: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(0.0, 0.0))
	var index: int = 0
	while index <= 32:
		var angle: float = lerpf(-1.4, 1.4, float(index) / 32.0)
		var radius: float = s * 0.68 * (0.91 + 0.09 * cos(angle * 8.0))
		points.append(Vector2(sin(angle) * radius, -cos(angle) * radius - s * 0.02))
		index += 1
	_poly(parent, points, color)
	var ray: int = -3
	while ray <= 3:
		var angle: float = float(ray) * 0.3
		_line(parent, PackedVector2Array([
			Vector2.ZERO, Vector2(sin(angle) * s * 0.54, -cos(angle) * s * 0.54),
		]), maxf(1.5, s * 0.02), color)
		ray += 1


static func _s_seastar(parent: Node2D, s: float, color: Color) -> void:
	var star: Node2D = Node2D.new()
	star.position = Vector2(0.0, -s * 0.38)
	_poly(star, _star_points(s * 0.38, 5, 0.56), color)
	parent.add_child(star)


## 12 小鸟：海鸥式展翅折线。
static func _p_bird(parent: Node2D, s: float, color: Color) -> void:
	_line(parent, PackedVector2Array([
		Vector2(-s * 0.5, -s * 0.32),
		Vector2(-s * 0.26, -s * 0.6),
		Vector2(0.0, -s * 0.4),
		Vector2(s * 0.26, -s * 0.6),
		Vector2(s * 0.5, -s * 0.32),
	]), s * 0.09, color)


static func _s_branch(parent: Node2D, s: float, color: Color) -> void:
	_line(parent, PackedVector2Array([
		Vector2(-s * 0.34, 0.0), Vector2(-s * 0.08, -s * 0.3), Vector2(s * 0.24, -s * 0.52),
	]), s * 0.06, color)
	_round_leaf(parent, s, color, Vector2(-s * 0.08, -s * 0.3), -52.0, 0.3)
	_round_leaf(parent, s, color, Vector2(s * 0.1, -s * 0.44), 38.0, 0.28)


## 13 石堆：三块卵石叠放。
static func _p_stones(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(-s * 0.24, -s * 0.13, s * 0.26, s * 0.14, 20), color)
	_poly(parent, _disk(s * 0.24, -s * 0.12, s * 0.24, s * 0.13, 20), color)
	_poly(parent, _disk(0.0, -s * 0.36, s * 0.28, s * 0.18, 20), color)


static func _s_pebble_grass(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(-s * 0.12, -s * 0.1, s * 0.26, s * 0.12, 20), color)
	var index: int = 0
	while index < 3:
		var blade: Node2D = Node2D.new()
		blade.position = Vector2(s * (0.16 + float(index) * 0.12), 0.0)
		blade.rotation = deg_to_rad(-24.0 + float(index) * 24.0)
		_poly(blade, _teardrop(s * 0.34, s * 0.11, 0.6), color)
		parent.add_child(blade)
		index += 1


# ── 非自然景物 ────────────────────────────────────────────────────

## 14 小屋：屋顶 + 屋身 + 烟囱。
static func _p_house(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _rect_points(0.0, -s * 0.28, s * 0.84, s * 0.56), color)
	_poly(parent, PackedVector2Array([
		Vector2(-s * 0.5, -s * 0.56), Vector2(0.0, -s * 0.92), Vector2(s * 0.5, -s * 0.56),
	]), color)
	_poly(parent, _rect_points(s * 0.3, -s * 0.8, s * 0.12, s * 0.22), color)


static func _s_tree(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _rect_points(0.0, -s * 0.16, s * 0.1, s * 0.32), color)
	_poly(parent, _disk(0.0, -s * 0.48, s * 0.3, s * 0.3, 24), color)
	_poly(parent, _disk(-s * 0.2, -s * 0.4, s * 0.18, s * 0.18, 18), color)
	_poly(parent, _disk(s * 0.2, -s * 0.42, s * 0.18, s * 0.18, 18), color)


## 15 齿轮。
static func _p_gear(parent: Node2D, s: float, color: Color) -> void:
	var gear: Node2D = Node2D.new()
	gear.position = Vector2(0.0, -s * 0.44)
	_poly(gear, _gear_points(s * 0.44, 10, 0.78), color)
	parent.add_child(gear)


static func _s_screw(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(0.0, -s * 0.34, s * 0.24, s * 0.24), color)
	_line(parent, PackedVector2Array([
		Vector2(-s * 0.12, -s * 0.34), Vector2(s * 0.12, -s * 0.34),
	]), maxf(2.0, s * 0.05), color)
	_line(parent, PackedVector2Array([
		Vector2(0.0, -s * 0.46), Vector2(0.0, -s * 0.22),
	]), maxf(2.0, s * 0.05), color)


## 16 灯泡。
static func _p_bulb(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(0.0, -s * 0.6, s * 0.3, s * 0.3, 24), color)
	_poly(parent, _rect_points(0.0, -s * 0.3, s * 0.26, s * 0.18), color)
	_poly(parent, _rect_points(0.0, -s * 0.14, s * 0.22, s * 0.14), color)
	_line(parent, PackedVector2Array([
		Vector2(-s * 0.11, -s * 0.24), Vector2(s * 0.11, -s * 0.24),
	]), maxf(1.5, s * 0.025), color)


static func _s_rays(parent: Node2D, s: float, color: Color) -> void:
	var center: Vector2 = Vector2(0.0, -s * 0.42)
	_poly(parent, _disk(center.x, center.y, s * 0.12, s * 0.12), color)
	var index: int = 0
	while index < 10:
		var angle: float = TAU * float(index) / 10.0
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		_line(parent, PackedVector2Array([
			center + direction * s * 0.2, center + direction * s * 0.36,
		]), maxf(2.0, s * 0.04), color)
		index += 1


## 17 礼物盒。
static func _p_gift(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _rect_points(0.0, -s * 0.3, s * 0.8, s * 0.6), color)
	_poly(parent, _rect_points(0.0, -s * 0.3, s * 0.14, s * 0.6), color)
	_poly(parent, PackedVector2Array([
		Vector2(0.0, -s * 0.62), Vector2(-s * 0.3, -s * 0.78), Vector2(-s * 0.26, -s * 0.56),
	]), color)
	_poly(parent, PackedVector2Array([
		Vector2(0.0, -s * 0.62), Vector2(s * 0.3, -s * 0.78), Vector2(s * 0.26, -s * 0.56),
	]), color)


static func _s_balloon(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(0.0, -s * 0.58, s * 0.22, s * 0.27, 22), color)
	_poly(parent, PackedVector2Array([
		Vector2(-s * 0.06, -s * 0.32), Vector2(s * 0.06, -s * 0.32), Vector2(0.0, -s * 0.26),
	]), color)
	_line(parent, PackedVector2Array([
		Vector2(0.0, -s * 0.26), Vector2(s * 0.08, -s * 0.16), Vector2(-s * 0.06, -s * 0.06), Vector2(0.0, 0.0),
	]), maxf(1.5, s * 0.025), color)


## 18 皇冠。
static func _p_crown(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, PackedVector2Array([
		Vector2(-s * 0.46, -s * 0.42),
		Vector2(-s * 0.46, -s * 0.78),
		Vector2(-s * 0.23, -s * 0.58),
		Vector2(0.0, -s * 0.86),
		Vector2(s * 0.23, -s * 0.58),
		Vector2(s * 0.46, -s * 0.78),
		Vector2(s * 0.46, -s * 0.42),
	]), color)
	_poly(parent, _rect_points(0.0, -s * 0.36, s * 0.98, s * 0.12), color)


static func _s_gem(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, PackedVector2Array([
		Vector2(0.0, -s * 0.72), Vector2(s * 0.26, -s * 0.5), Vector2(0.0, -s * 0.22), Vector2(-s * 0.26, -s * 0.5),
	]), color)
	_line(parent, PackedVector2Array([
		Vector2(-s * 0.26, -s * 0.5), Vector2(s * 0.26, -s * 0.5),
	]), maxf(1.5, s * 0.025), color)


## 19 火箭。
static func _p_rocket(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, PackedVector2Array([
		Vector2(-s * 0.16, -s * 0.12),
		Vector2(-s * 0.16, -s * 0.6),
		Vector2(0.0, -s * 0.86),
		Vector2(s * 0.16, -s * 0.6),
		Vector2(s * 0.16, -s * 0.12),
	]), color)
	_poly(parent, PackedVector2Array([
		Vector2(-s * 0.16, -s * 0.34), Vector2(-s * 0.38, -s * 0.08), Vector2(-s * 0.16, -s * 0.08),
	]), color)
	_poly(parent, PackedVector2Array([
		Vector2(s * 0.16, -s * 0.34), Vector2(s * 0.38, -s * 0.08), Vector2(s * 0.16, -s * 0.08),
	]), color)
	var flame: Node2D = Node2D.new()
	flame.position = Vector2(0.0, -s * 0.08)
	flame.rotation = deg_to_rad(180.0)
	_poly(flame, _teardrop(s * 0.28, s * 0.2, 0.0), color)
	parent.add_child(flame)


static func _s_planet(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(0.0, -s * 0.42, s * 0.28, s * 0.28), color)
	_poly(parent, _disk(-s * 0.1, -s * 0.48, s * 0.06, s * 0.06, 12), color)
	_poly(parent, _disk(s * 0.1, -s * 0.34, s * 0.04, s * 0.04, 12), color)
	var ring: Node2D = Node2D.new()
	ring.position = Vector2(s * 0.36, -s * 0.66)
	_poly(ring, _star_points(s * 0.1), color)
	parent.add_child(ring)


## 20 音符。
static func _p_note(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(-s * 0.18, -s * 0.14, s * 0.19, s * 0.13, 20), color)
	_poly(parent, _rect_points(0.0, -s * 0.48, s * 0.06, s * 0.72), color)
	_poly(parent, PackedVector2Array([
		Vector2(0.0, -s * 0.84), Vector2(s * 0.3, -s * 0.68), Vector2(s * 0.24, -s * 0.52), Vector2(0.0, -s * 0.62),
	]), color)


static func _s_double_note(parent: Node2D, s: float, color: Color) -> void:
	_poly(parent, _disk(-s * 0.26, -s * 0.14, s * 0.15, s * 0.11, 18), color)
	_poly(parent, _disk(s * 0.26, -s * 0.14, s * 0.15, s * 0.11, 18), color)
	_poly(parent, _rect_points(-s * 0.12, -s * 0.46, s * 0.05, s * 0.64), color)
	_poly(parent, _rect_points(s * 0.4, -s * 0.46, s * 0.05, s * 0.64), color)
	_poly(parent, _rect_points(s * 0.14, -s * 0.78, s * 0.57, s * 0.1), color)
