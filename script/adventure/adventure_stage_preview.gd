extends Control

## 百人团舞台的关卡示意图：手动摆放关卡椭圆（每行 10 格）并画关卡之间的连线。
##
## 同行相邻用水平直线；行末 → 下一行行首用三次贝塞尔曲线绕下去（先竖直下探、
## 中间水平横穿、再竖直下落到下一行首格顶边），形状与过关过场里的椭圆串一致。
##
## 关卡节点由舞台（adventure_stage.gd）创建后 add_child 进来，本脚本只负责位置与连线。
## 子节点的**原点 = 椭圆中心**，连线和马里奥都按中心相对定位。

const COLUMNS: int = 10
## 与舞台里的 ELLIPSE_W / ELLIPSE_H 保持一致。
const CELL_W: float = 68.0
const CELL_H: float = 58.0
const GAP_X: float = 14.0
const GAP_Y: float = 14.0
## 和过关过场里的椭圆串同款线宽。
const LINE_WIDTH: float = 2.0
## 直线两端留一点缝，别把椭圆的边糊住。
const LINE_INSET: float = 4.0
const CURVE_STEPS: int = 26

var line_color: Color = Color(0.15, 0.2, 0.3, 0.65):
	set(value):
		line_color = value
		queue_redraw()


## 按当前子节点数量重排；最后一行不满时左对齐（第 11 关从最左开始）。
func relayout() -> void:
	var count: int = get_child_count()
	var rows: int = maxi(ceili(float(count) / float(COLUMNS)), 1)
	custom_minimum_size = Vector2(
		float(COLUMNS) * CELL_W + float(COLUMNS - 1) * GAP_X,
		float(rows) * CELL_H + float(rows - 1) * GAP_Y
	)
	size = custom_minimum_size
	for index: int in range(count):
		var cell: Node2D = get_child(index) as Node2D
		if cell == null:
			continue
		cell.position = Vector2(
			float(index % COLUMNS) * (CELL_W + GAP_X) + CELL_W * 0.5,
			floorf(float(index) / float(COLUMNS)) * (CELL_H + GAP_Y) + CELL_H * 0.5
		)
	queue_redraw()


func _draw() -> void:
	var count: int = get_child_count()
	for index: int in range(count - 1):
		var from_cell: Node2D = get_child(index) as Node2D
		var to_cell: Node2D = get_child(index + 1) as Node2D
		if from_cell == null or to_cell == null:
			continue
		if index % COLUMNS == COLUMNS - 1:
			draw_polyline(_wrap_points(from_cell, to_cell), line_color, LINE_WIDTH, true)
			continue
		var y: float = from_cell.position.y
		draw_line(
			Vector2(from_cell.position.x + CELL_W * 0.5 + LINE_INSET, y),
			Vector2(to_cell.position.x - CELL_W * 0.5 - LINE_INSET, y),
			line_color,
			LINE_WIDTH,
			true
		)


## 行末 → 下一行行首：三个控制点让曲线竖直下探、水平横穿、再竖直落下。
func _wrap_points(from_cell: Node2D, to_cell: Node2D) -> PackedVector2Array:
	var start: Vector2 = Vector2(
		from_cell.position.x, from_cell.position.y + CELL_H * 0.5
	)
	var end: Vector2 = Vector2(to_cell.position.x, to_cell.position.y - CELL_H * 0.5)
	var mid_y: float = (start.y + end.y) * 0.5
	var control_a: Vector2 = Vector2(start.x, mid_y)
	var control_b: Vector2 = Vector2(end.x, mid_y)
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(CURVE_STEPS + 1):
		var t: float = float(step) / float(CURVE_STEPS)
		points.append(_cubic_point(start, control_a, control_b, end, t))
	return points


func _cubic_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return (
		p0 * (u * u * u)
		+ p1 * (3.0 * u * u * t)
		+ p2 * (3.0 * u * t * t)
		+ p3 * (t * t * t)
	)
