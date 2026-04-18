extends Node2D

var line: Line2D
var drawing: bool = false
var points: Array[Vector2] = []          # 网格对齐的点
var last_point: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.ZERO
const STEP: float = 32.0
const LINE_WIDTH: float = 62.0

func _ready() -> void:
	line = Line2D.new()
	add_child(line)
	line.width = LINE_WIDTH
	line.default_color = Color.WHITE
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drawing(get_global_mouse_position())
			else:
				stop_drawing()
	elif event is InputEventScreenTouch:
		if event.pressed:
			start_drawing(event.position)
		else:
			stop_drawing()
	elif event is InputEventMouseMotion and drawing:
		update_drawing(get_global_mouse_position())
	elif event is InputEventScreenDrag and drawing:
		update_drawing(event.position)

func start_drawing(pos: Vector2) -> void:
	drawing = true
	var snapped = snap_to_grid(pos)
	points.clear()
	points.append(snapped)
	last_point = snapped
	last_direction = Vector2.ZERO
	line.points = points

func stop_drawing() -> void:
	drawing = false
	print("绘制结束，共 %d 个点" % points.size())
	# 绘制完成后，通知管道生成器
	if has_node("PipeBuilder"):
		$PipeBuilder.build_pipes()

func update_drawing(current_pos: Vector2) -> void:
	if points.is_empty():
		return

	var snapped = snap_to_grid(current_pos)
	var diff = snapped - last_point

	# 确定移动方向（正交）
	var move_dir = Vector2.ZERO
	if abs(diff.x) > abs(diff.y):
		move_dir = Vector2(sign(diff.x), 0.0)
	else:
		move_dir = Vector2(0.0, sign(diff.y))

	if move_dir == Vector2.ZERO:
		return

	# ---------- 回退检测（改进版，支持拐角）----------
	var is_reverse = false
	var last_seg_length: float = 0.0
	if points.size() >= 2:
		var prev = points[-2]
		last_seg_length = last_point.distance_to(prev)
		var last_seg_dir = (last_point - prev).normalized()
		if last_seg_dir.dot(move_dir) < -0.9:
			is_reverse = true

	if is_reverse:
		# 反向移动所需的最小距离应等于最后一段的长度
		var axis_dist = abs(diff.x) if move_dir.x != 0 else abs(diff.y)
		if axis_dist >= last_seg_length:
			# 生成候选点：反向移动 last_seg_length 距离
			var candidate = last_point + move_dir * last_seg_length
			# 如果候选点与倒数第二个点接近（即完全回退了最后一段），则删除最后一个点
			if candidate.distance_squared_to(points[-2]) < 0.1:
				points.pop_back()
				if points.size() > 0:
					last_point = points.back()
					if points.size() >= 2:
						var new_prev = points[-2]
						last_direction = (last_point - new_prev).normalized()
					else:
						last_direction = Vector2.ZERO
				else:
					# 所有点被删除，重新开始
					last_point = candidate
					points.append(candidate)
					last_direction = Vector2.ZERO
				line.points = points
		return

	# ---------- 正常前进逻辑 ----------
	var direction_changed = (last_direction != Vector2.ZERO and move_dir != last_direction)
	var required_step = STEP * 2.0 if direction_changed else STEP

	var axis_dist = abs(diff.x) if move_dir.x != 0 else abs(diff.y)
	if axis_dist < required_step:
		return

	var candidate = last_point + move_dir * required_step

	# 检查几何相交与视觉重叠
	if can_add_point(candidate) and not would_overlap_visually(candidate):
		points.append(candidate)
		last_point = candidate
		last_direction = move_dir
		line.points = points

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x / STEP) * STEP, round(pos.y / STEP) * STEP)

func can_add_point(new_point: Vector2) -> bool:
	if points.size() < 2:
		return true
	var seg_start = last_point
	var seg_end = new_point
	for i in range(points.size() - 2):
		var p1 = points[i]
		var p2 = points[i + 1]
		if segments_intersect(p1, p2, seg_start, seg_end):
			return false
	return true

func would_overlap_visually(new_point: Vector2) -> bool:
	if points.size() < 2:
		return false
	var seg_start = last_point
	var seg_end = new_point
	var is_horizontal = (seg_start.y == seg_end.y)
	var y_level = seg_start.y if is_horizontal else 0.0
	var x_level = seg_start.x if not is_horizontal else 0.0
	var x_min = min(seg_start.x, seg_end.x)
	var x_max = max(seg_start.x, seg_end.x)
	var y_min = min(seg_start.y, seg_end.y)
	var y_max = max(seg_start.y, seg_end.y)

	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]
		if i == points.size() - 2:
			continue
		var other_h = (p1.y == p2.y)
		if is_horizontal and other_h:
			if abs(y_level - p1.y) < LINE_WIDTH:
				var ox_min = min(p1.x, p2.x)
				var ox_max = max(p1.x, p2.x)
				if not (x_max < ox_min or x_min > ox_max):
					return true
		elif not is_horizontal and not other_h:
			if abs(x_level - p1.x) < LINE_WIDTH:
				var oy_min = min(p1.y, p2.y)
				var oy_max = max(p1.y, p2.y)
				if not (y_max < oy_min or y_min > oy_max):
					return true
	return false

# 几何相交函数
func segments_intersect(a1, a2, b1, b2):
	var d1 = cross(b1, b2, a1)
	var d2 = cross(b1, b2, a2)
	var d3 = cross(a1, a2, b1)
	var d4 = cross(a1, a2, b2)
	if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
		return true
	if is_zero_approx(d1) and on_segment(b1, b2, a1): return true
	if is_zero_approx(d2) and on_segment(b1, b2, a2): return true
	if is_zero_approx(d3) and on_segment(a1, a2, b1): return true
	if is_zero_approx(d4) and on_segment(a1, a2, b2): return true
	return false

func cross(p1, p2, p3):
	return (p3.x - p1.x) * (p2.y - p1.y) - (p2.x - p1.x) * (p3.y - p1.y)

func on_segment(p1, p2, p):
	return p.x >= min(p1.x, p2.x) - 0.001 and p.x <= max(p1.x, p2.x) + 0.001 and \
		   p.y >= min(p1.y, p2.y) - 0.001 and p.y <= max(p1.y, p2.y) + 0.001