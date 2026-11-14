extends Control

## 百人团舞台的关卡示意图：按蛇形路线摆放关卡椭圆（每行 10 格）并画关卡之间的连线。
##
## 路线：第 1 行从左到右（1..10）、第 2 行从右到左（11..20）、第 3 行再从左到右……
## 行末与下一行行首落在同一侧，用向行外凸出的 C 形弯连接（右侧 10→11、左侧 20→21）。
## 所有线都从椭圆边缘内侧起笔，端点压进椭圆里，整条路线不留缝。
##
## 关卡节点由舞台（adventure_stage.gd）创建后 add_child 进来，本脚本只负责位置与连线。
## 子节点的**原点 = 椭圆中心**，连线和马里奥都按中心相对定位。

const COLUMNS: int = 10
## 与 object/adventure/level_node.tscn 里的椭圆尺寸保持一致。
const CELL_W: float = 68.0
const CELL_H: float = 58.0
const GAP_X: float = 14.0
const GAP_Y: float = 14.0
## 和过关过场里的椭圆串同款线宽。
const LINE_WIDTH: float = 2.0
## 连线外侧的黑色描边：每边 2px，先画粗黑线打底，再把彩色线盖在上面。
const LINE_OUTLINE: float = 2.0
const LINE_OUTLINE_COLOR: Color = Color(0, 0, 0, 1)
## level_node.svg 的椭圆 rx=32、描边 2px（外沿 33）；线端点再往里伸 2px，
## 让线真正压进椭圆边缘，而不是留一道可见的缝。
const ELLIPSE_RX: float = 33.0
const LINE_OVERLAP: float = 2.0
const EDGE_X: float = ELLIPSE_RX - LINE_OVERLAP
## 折返线：先水平向行外伸出，再画一个向外凸的三次贝塞尔 C 形弯落到下一行。
const WRAP_OUT: float = 24.0
const WRAP_BULGE: float = 64.0
## 曲线最外点 = WRAP_OUT + 0.75 * WRAP_BULGE，左右各留这么多空白给折返线。
const WRAP_PAD: float = WRAP_OUT + WRAP_BULGE * 0.75 + 2.0
const CURVE_STEPS: int = 24

var line_color: Color = Color(0.15, 0.2, 0.3, 0.65):
	set(value):
		line_color = value
		queue_redraw()


## 按当前子节点数量重排；最后一行不满时按该行的行进方向对齐（左行靠左、右行靠右）。
func relayout() -> void:
	var count: int = get_child_count()
	var rows: int = maxi(ceili(float(count) / float(COLUMNS)), 1)
	custom_minimum_size = Vector2(
		float(COLUMNS) * CELL_W + float(COLUMNS - 1) * GAP_X + WRAP_PAD * 2.0,
		float(rows) * CELL_H + float(rows - 1) * GAP_Y
	)
	size = custom_minimum_size
	for index: int in range(count):
		var cell: Node2D = get_child(index) as Node2D
		if cell == null:
			continue
		var row: int = int(floorf(float(index) / float(COLUMNS)))
		var column: int = index % COLUMNS
		# 偶数行反过来摆：11 在最右、20 在最左，正好接住上一行的折返弯。
		if row % 2 == 1:
			column = COLUMNS - 1 - column
		cell.position = Vector2(
			WRAP_PAD + float(column) * (CELL_W + GAP_X) + CELL_W * 0.5,
			float(row) * (CELL_H + GAP_Y) + CELL_H * 0.5
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
			# 行末在右（0、2…行）就从右侧绕，行末在左（1、3…行）就从左侧绕。
			var side: float = 1.0 if (int(floorf(float(index) / float(COLUMNS))) % 2) == 0 else -1.0
			var points: PackedVector2Array = _wrap_points(from_cell, to_cell, side)
			draw_polyline(points, LINE_OUTLINE_COLOR, LINE_WIDTH + LINE_OUTLINE * 2.0, true)
			draw_polyline(points, line_color, LINE_WIDTH, true)
			continue
		var y: float = from_cell.position.y
		var start: Vector2 = Vector2(minf(from_cell.position.x, to_cell.position.x) + EDGE_X, y)
		var end: Vector2 = Vector2(maxf(from_cell.position.x, to_cell.position.x) - EDGE_X, y)
		draw_line(start, end, LINE_OUTLINE_COLOR, LINE_WIDTH + LINE_OUTLINE * 2.0, true)
		draw_line(start, end, line_color, LINE_WIDTH, true)


## 行末 → 下一行行首：水平出线 → 向外凸的 C 形弯下折 → 水平回到下一行首格。
## 三段拼成一条 polyline，起点/终点都压在两颗椭圆的外侧边缘上，整条路线连续。
func _wrap_points(from_cell: Node2D, to_cell: Node2D, side: float) -> PackedVector2Array:
	var y1: float = from_cell.position.y
	var y2: float = to_cell.position.y
	var start_edge: float = from_cell.position.x + side * EDGE_X
	var end_edge: float = to_cell.position.x + side * EDGE_X
	var out_x: float = start_edge + side * WRAP_OUT
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(start_edge, y1))
	points.append(Vector2(out_x, y1))
	for step: int in range(1, CURVE_STEPS + 1):
		var t: float = float(step) / float(CURVE_STEPS)
		points.append(_cubic_point(
			Vector2(out_x, y1),
			Vector2(out_x + side * WRAP_BULGE, y1),
			Vector2(out_x + side * WRAP_BULGE, y2),
			Vector2(out_x, y2),
			t
		))
	points.append(Vector2(end_edge, y2))
	return points


func _cubic_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return (
		p0 * (u * u * u)
		+ p1 * (3.0 * u * u * t)
		+ p2 * (3.0 * u * t * t)
		+ p3 * (t * t * t)
	)
