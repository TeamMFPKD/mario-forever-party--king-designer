extends Node2D

const STEP: float = 32.0
const CORNER_STEP: float = 64.0
const LINE_WIDTH: float = 62.0
const HANDLER_SCENE = preload("res://object/edit/clear_pipe/clear_pipe_node_handler.tscn")

var line_data_list: Array[Dictionary] = []
var current_line_index: int = -1
var drawing: bool = false
var editing_line_index: int = -1
var dragging_line_index: int = -1
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_original_points: Array[Vector2] = []

var handlers_node: Node2D
var lines_node: Node2D

func _ready() -> void:
	handlers_node = Node2D.new()
	handlers_node.name = "Handlers"
	add_child(handlers_node)
	
	lines_node = Node2D.new()
	lines_node.name = "Lines"
	add_child(lines_node)

func _input(event: InputEvent) -> void:
	if dragging_line_index >= 0:
		handle_dragging(event)
		return
	
	if editing_line_index >= 0:
		handle_editing(event)
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var click_pos = get_local_mouse_position()
				var clicked_line = get_line_at_position(click_pos)
				if clicked_line >= 0:
					start_dragging_line(clicked_line, click_pos)
				else:
					start_drawing(click_pos)
			else:
				stop_drawing()
	elif event is InputEventScreenTouch:
		if event.pressed:
			var click_pos = to_local(event.position)
			var clicked_line = get_line_at_position(click_pos)
			if clicked_line >= 0:
				start_dragging_line(clicked_line, click_pos)
			else:
				start_drawing(click_pos)
		else:
			stop_drawing()
	elif event is InputEventMouseMotion and drawing:
		update_drawing(get_local_mouse_position())
	elif event is InputEventScreenDrag and drawing:
		update_drawing(to_local(event.position))

func get_line_at_position(pos: Vector2) -> int:
	for i in range(line_data_list.size()):
		var line_data = line_data_list[i]
		var line: Line2D = line_data.line
		var points: Array[Vector2] = line_data.points
		if points.size() < 2:
			continue
		for j in range(points.size() - 1):
			var p1 = points[j]
			var p2 = points[j + 1]
			if is_point_near_segment(pos, p1, p2, LINE_WIDTH / 2.0):
				return i
	return -1

func is_point_near_segment(point: Vector2, seg_start: Vector2, seg_end: Vector2, threshold: float) -> bool:
	var seg_vec = seg_end - seg_start
	var seg_len = seg_vec.length()
	if seg_len < 0.001:
		return point.distance_to(seg_start) <= threshold
	
	var seg_dir = seg_vec.normalized()
	var point_vec = point - seg_start
	var projection = point_vec.dot(seg_dir)
	projection = clamp(projection, 0.0, seg_len)
	var closest_point = seg_start + seg_dir * projection
	return point.distance_to(closest_point) <= threshold

func start_dragging_line(line_idx: int, pos: Vector2) -> void:
	dragging_line_index = line_idx
	drag_start_pos = snap_to_grid(pos)
	drag_original_points = line_data_list[line_idx].points.duplicate()
	print("开始拖动线条 %d" % line_idx)

func handle_dragging(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			finish_dragging()
	elif event is InputEventScreenTouch:
		if not event.pressed:
			finish_dragging()
	elif event is InputEventMouseMotion:
		update_dragging(get_local_mouse_position())
	elif event is InputEventScreenDrag:
		update_dragging(to_local(event.position))

func handle_editing(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				stop_drawing()
	elif event is InputEventScreenTouch:
		if not event.pressed:
			stop_drawing()
	elif event is InputEventMouseMotion:
		update_drawing(get_local_mouse_position())
	elif event is InputEventScreenDrag:
		update_drawing(to_local(event.position))

func update_dragging(current_pos: Vector2) -> void:
	if dragging_line_index < 0:
		return
	
	var snapped = snap_to_grid(current_pos)
	var delta = snapped - drag_start_pos
	
	if delta == Vector2.ZERO:
		return
	
	var line_data = line_data_list[dragging_line_index]
	var new_points: Array[Vector2] = []
	for p in drag_original_points:
		new_points.append(p + delta)
	
	if would_lines_overlap(dragging_line_index, new_points):
		print("拖动被阻止: 线条 %d 会与其他线条重叠" % dragging_line_index)
		return
	
	line_data.points = new_points
	line_data.line.points = new_points
	update_handlers_for_line(dragging_line_index)

func finish_dragging() -> void:
	if dragging_line_index >= 0:
		var line_data = line_data_list[dragging_line_index]
		var new_points = line_data.points
		var delta = new_points[0] - drag_original_points[0] if new_points.size() > 0 else Vector2.ZERO
		
		if delta != Vector2.ZERO:
			if would_lines_overlap(dragging_line_index, new_points):
				line_data.points = drag_original_points.duplicate()
				line_data.line.points = drag_original_points
				update_handlers_for_line(dragging_line_index)
			else:
				rebuild_pipes()
	
	dragging_line_index = -1
	drag_original_points.clear()
	print("结束拖动")

func would_lines_overlap(exclude_idx: int, new_points: Array[Vector2]) -> bool:
	if new_points.size() < 2:
		return false
	
	for i in range(line_data_list.size()):
		if i == exclude_idx:
			continue
		var other_points = line_data_list[i].points
		if check_lines_overlap(new_points, other_points):
			return true
	return false

func check_lines_overlap(points1: Array[Vector2], points2: Array[Vector2]) -> bool:
	if points1.size() < 2 or points2.size() < 2:
		return false
	
	for i in range(points1.size() - 1):
		var p1_start = points1[i]
		var p1_end = points1[i + 1]
		for j in range(points2.size() - 1):
			var p2_start = points2[j]
			var p2_end = points2[j + 1]
			if segments_too_close(p1_start, p1_end, p2_start, p2_end):
				return true
	return false

func segments_too_close(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var a_horizontal = abs(a1.y - a2.y) < 0.1
	var b_horizontal = abs(b1.y - b2.y) < 0.1
	
	if a_horizontal and b_horizontal:
		var y_diff = abs(a1.y - b1.y)
		if y_diff < LINE_WIDTH:
			var a_min_x = min(a1.x, a2.x)
			var a_max_x = max(a1.x, a2.x)
			var b_min_x = min(b1.x, b2.x)
			var b_max_x = max(b1.x, b2.x)
			if not (a_max_x < b_min_x or a_min_x > b_max_x):
				print("检测到水平线重叠: y_diff=%.1f, a=[%.0f,%.0f], b=[%.0f,%.0f]" % [y_diff, a_min_x, a_max_x, b_min_x, b_max_x])
				return true
	elif not a_horizontal and not b_horizontal:
		var x_diff = abs(a1.x - b1.x)
		if x_diff < LINE_WIDTH:
			var a_min_y = min(a1.y, a2.y)
			var a_max_y = max(a1.y, a2.y)
			var b_min_y = min(b1.y, b2.y)
			var b_max_y = max(b1.y, b2.y)
			if not (a_max_y < b_min_y or a_min_y > b_max_y):
				print("检测到垂直线重叠: x_diff=%.1f, a=[%.0f,%.0f], b=[%.0f,%.0f]" % [x_diff, a_min_y, a_max_y, b_min_y, b_max_y])
				return true
	else:
		var h_start: Vector2
		var h_end: Vector2
		var v_start: Vector2
		var v_end: Vector2
		
		if a_horizontal:
			h_start = a1
			h_end = a2
			v_start = b1
			v_end = b2
		else:
			h_start = b1
			h_end = b2
			v_start = a1
			v_end = a2
		
		var h_min_x = min(h_start.x, h_end.x)
		var h_max_x = max(h_start.x, h_end.x)
		var v_min_y = min(v_start.y, v_end.y)
		var v_max_y = max(v_start.y, v_end.y)
		
		if v_start.x >= h_min_x and v_start.x <= h_max_x:
			if h_start.y >= v_min_y and h_start.y <= v_max_y:
				print("检测到水平垂直交叉: 水平(%.0f,%.0f)->(%.0f,%.0f), 垂直(%.0f,%.0f)->(%.0f,%.0f)" % [h_start.x, h_start.y, h_end.x, h_end.y, v_start.x, v_start.y, v_end.x, v_end.y])
				return true
	
	return false

func start_drawing(pos: Vector2) -> void:
	var snapped = snap_to_grid(pos)
	
	if is_point_on_any_line(snapped):
		print("起点与现有线条重叠，无法创建新线条")
		return
	
	var new_line_data = create_new_line(snapped)
	line_data_list.append(new_line_data)
	current_line_index = line_data_list.size() - 1
	
	var end_handler = create_handler(snapped, current_line_index, true)
	end_handler.set_held(true)
	line_data_list[current_line_index].end_handler = end_handler
	update_handler_directions(current_line_index)
	
	drawing = true
	print("=== 开始绘制新线条 %d，起点: (%.1f, %.1f) ===" % [current_line_index, snapped.x, snapped.y])

func create_new_line(start_pos: Vector2) -> Dictionary:
	var line = Line2D.new()
	line.width = LINE_WIDTH
	line.default_color = Color.WHITE
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	lines_node.add_child(line)
	
	var points: Array[Vector2] = [start_pos]
	line.points = points
	
	var start_handler = create_handler(start_pos, line_data_list.size(), false)
	
	return {
		"line": line,
		"points": points,
		"last_direction": Vector2.ZERO,
		"start_handler": start_handler,
		"end_handler": null
	}

func create_handler(pos: Vector2, line_idx: int, is_tail: bool) -> Node2D:
	var handler = HANDLER_SCENE.instantiate()
	handler.position = pos
	handler.line_index = line_idx
	handler.set_tail(is_tail)
	handler.handler_pressed.connect(_on_handler_pressed)
	handlers_node.add_child(handler)
	return handler

func _on_handler_pressed(handler: Node2D) -> void:
	if not handler.is_tail:
		return
	editing_line_index = handler.line_index
	handler.set_held(true)
	drawing = true
	print("开始编辑线条 %d" % editing_line_index)

func stop_drawing() -> void:
	if not drawing:
		return
	
	drawing = false
	
	var active_idx = editing_line_index if editing_line_index >= 0 else current_line_index
	
	if active_idx >= 0 and active_idx < line_data_list.size():
		var line_data = line_data_list[active_idx]
		var points = line_data.points
		
		if points.size() < 2:
			remove_line(active_idx)
		else:
			if line_data.end_handler:
				line_data.end_handler.set_held(false)
				line_data.end_handler.position = points[points.size() - 1]
			update_handler_directions(active_idx)
			
			print("=== 绘制结束，线条 %d，共 %d 个点 ===" % [active_idx, points.size()])
			_print_points_debug(points)
			rebuild_pipes()
	
	current_line_index = -1
	editing_line_index = -1

func remove_line(line_idx: int) -> void:
	if line_idx < 0 or line_idx >= line_data_list.size():
		return
	
	var line_data = line_data_list[line_idx]
	if line_data.line:
		line_data.line.queue_free()
	if line_data.start_handler:
		line_data.start_handler.queue_free()
	if line_data.end_handler:
		line_data.end_handler.queue_free()
	
	line_data_list.remove_at(line_idx)
	
	for i in range(line_data_list.size()):
		var ld = line_data_list[i]
		ld.start_handler.line_index = i
		if ld.end_handler:
			ld.end_handler.line_index = i

func update_drawing(current_pos: Vector2) -> void:
	var active_idx = editing_line_index if editing_line_index >= 0 else current_line_index
	if active_idx < 0 or active_idx >= line_data_list.size():
		return
	
	var line_data = line_data_list[active_idx]
	var points: Array[Vector2] = line_data.points
	var last_point: Vector2 = points.back() if points.size() > 0 else Vector2.ZERO
	var last_direction: Vector2 = line_data.last_direction
	
	if points.is_empty():
		return

	var snapped = snap_to_grid(current_pos)
	var diff = snapped - last_point

	var move_dir = Vector2.ZERO
	if abs(diff.x) > abs(diff.y):
		move_dir = Vector2(sign(diff.x), 0.0)
	else:
		move_dir = Vector2(0.0, sign(diff.y))

	if move_dir == Vector2.ZERO:
		return

	var is_reverse = false
	if points.size() >= 2:
		var prev = points[-2]
		var back_dir = Vector2.ZERO
		var vec_to_prev = prev - last_point
		if abs(vec_to_prev.x) > 0.1:
			back_dir = Vector2(sign(vec_to_prev.x), 0.0)
		elif abs(vec_to_prev.y) > 0.1:
			back_dir = Vector2(0.0, sign(vec_to_prev.y))
		if back_dir != Vector2.ZERO and move_dir == back_dir:
			is_reverse = true

	if is_reverse:
		var axis_dist = abs(diff.x) if move_dir.x != 0 else abs(diff.y)
		if axis_dist >= STEP:
			var candidate = last_point + move_dir * STEP
			var prev_point = points[-2]
			if candidate.distance_squared_to(prev_point) <= STEP * STEP + 1.0:
				points.pop_back()
				if points.size() > 0:
					line_data.last_direction = get_last_direction(points)
					update_line_and_handlers(active_idx)
					print("回退删除点，剩余 %d 个点" % points.size())
					_print_points_debug(points)
				else:
					points.append(candidate)
					line_data.last_direction = Vector2.ZERO
					update_line_and_handlers(active_idx)
			else:
				last_point = candidate
		return

	var direction_changed = (last_direction != Vector2.ZERO and move_dir != last_direction)
	
	if direction_changed:
		var straight_count = count_consecutive_same_direction(points, last_direction)
		if straight_count < 2:
			return
	
	var required_step = CORNER_STEP if direction_changed else STEP
	var axis_dist = abs(diff.x) if move_dir.x != 0 else abs(diff.y)
	if axis_dist < required_step:
		return

	var candidate = last_point + move_dir * required_step

	if can_add_point(points, candidate, active_idx) and not would_overlap_visually(points, candidate) and not would_overlap_other_lines(active_idx, points, candidate):
		points.append(candidate)
		line_data.last_direction = move_dir
		update_line_and_handlers(active_idx)
		print("添加点: (%.1f, %.1f)，方向: %s，步长: %d" % [candidate.x, candidate.y, dir_to_str(move_dir), required_step])
		_print_points_debug(points)

func update_line_and_handlers(line_idx: int) -> void:
	var line_data = line_data_list[line_idx]
	line_data.line.points = line_data.points
	
	if line_data.end_handler:
		var points = line_data.points
		if points.size() > 0:
			line_data.end_handler.position = points[points.size() - 1]
			update_handler_directions(line_idx)

func update_handlers_for_line(line_idx: int) -> void:
	var line_data = line_data_list[line_idx]
	var points = line_data.points
	
	if points.size() > 0:
		if line_data.start_handler:
			line_data.start_handler.position = points[0]
		if line_data.end_handler:
			line_data.end_handler.position = points[points.size() - 1]
			update_handler_directions(line_idx)

func update_handler_directions(line_idx: int) -> void:
	var line_data = line_data_list[line_idx]
	if not line_data.end_handler:
		return
	
	var points = line_data.points
	if points.size() < 1:
		return
	
	var tail_pos = points[points.size() - 1]
	var can_right = can_draw_in_direction(line_idx, tail_pos, Vector2.RIGHT)
	var can_left = can_draw_in_direction(line_idx, tail_pos, Vector2.LEFT)
	var can_up = can_draw_in_direction(line_idx, tail_pos, Vector2.UP)
	var can_down = can_draw_in_direction(line_idx, tail_pos, Vector2.DOWN)
	
	line_data.end_handler.set_draw_directions(can_right, can_left, can_up, can_down)

func can_draw_in_direction(line_idx: int, from_pos: Vector2, direction: Vector2) -> bool:
	var test_pos = from_pos + direction * STEP
	
	var line_data = line_data_list[line_idx]
	var points = line_data.points
	
	if points.size() >= 2:
		var last_dir = get_orthogonal_direction(points[-2], points[-1])
		if last_dir != Vector2.ZERO and direction != last_dir:
			return true
	
	for i in range(line_data_list.size()):
		var other_points = line_data_list[i].points
		for j in range(other_points.size()):
			if other_points[j].distance_squared_to(test_pos) < STEP * STEP * 0.25:
				return false
	
	return true

func get_last_direction(points: Array[Vector2]) -> Vector2:
	if points.size() < 2:
		return Vector2.ZERO
	return get_orthogonal_direction(points[-2], points[-1])

func count_consecutive_same_direction(points: Array[Vector2], dir_to_check: Vector2) -> int:
	if dir_to_check == Vector2.ZERO:
		return 0
	var count = 0
	var i = points.size() - 2
	while i >= 1:
		var p1 = points[i - 1]
		var p2 = points[i]
		var seg_dir = get_orthogonal_direction(p1, p2)
		if seg_dir == dir_to_check:
			count += 1
		else:
			break
		i -= 1
	if points.size() >= 2:
		var last_seg_dir = get_orthogonal_direction(points[-2], points[-1])
		if last_seg_dir == dir_to_check:
			count += 1
	return count

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x / STEP) * STEP, round(pos.y / STEP) * STEP)

func can_add_point(points: Array[Vector2], new_point: Vector2, exclude_line_idx: int) -> bool:
	if points.size() < 2:
		return true
	var seg_start = points.back()
	var seg_end = new_point
	for i in range(points.size() - 2):
		var p1 = points[i]
		var p2 = points[i + 1]
		if segments_intersect(p1, p2, seg_start, seg_end):
			return false
	return true

func would_overlap_visually(points: Array[Vector2], new_point: Vector2) -> bool:
	if points.size() < 2:
		return false
	var seg_start = points.back()
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

func would_overlap_other_lines(exclude_idx: int, points: Array[Vector2], new_point: Vector2) -> bool:
	if points.size() < 1:
		return false
	
	var seg_start = points.back()
	var seg_end = new_point
	
	print("检查新线段 (%.0f,%.0f)->(%.0f,%.0f) 是否与其他线条重叠，共 %d 条其他线条" % [seg_start.x, seg_start.y, seg_end.x, seg_end.y, line_data_list.size() - 1])
	
	for i in range(line_data_list.size()):
		if i == exclude_idx:
			continue
		var other_points = line_data_list[i].points
		if other_points.size() < 2:
			continue
		if check_new_segment_overlap(seg_start, seg_end, other_points):
			print("新线段 (%.0f,%.0f)->(%.0f,%.0f) 与线条 %d 重叠" % [seg_start.x, seg_start.y, seg_end.x, seg_end.y, i])
			return true
	return false

func check_new_segment_overlap(seg_start: Vector2, seg_end: Vector2, other_points: Array[Vector2]) -> bool:
	for j in range(other_points.size() - 1):
		var p1 = other_points[j]
		var p2 = other_points[j + 1]
		print("  检查与线段 (%.0f,%.0f)->(%.0f,%.0f)" % [p1.x, p1.y, p2.x, p2.y])
		if segments_too_close(seg_start, seg_end, p1, p2):
			return true
	return false

func is_point_on_any_line(point: Vector2) -> bool:
	for line_data in line_data_list:
		var points = line_data.points
		if points.size() < 2:
			continue
		for i in range(points.size() - 1):
			if is_point_near_segment(point, points[i], points[i + 1], LINE_WIDTH / 2.0):
				return true
	return false

func segments_intersect(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
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

func cross(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p3.x - p1.x) * (p2.y - p1.y) - (p2.x - p1.x) * (p3.y - p1.y)

func on_segment(p1: Vector2, p2: Vector2, p: Vector2) -> bool:
	return p.x >= min(p1.x, p2.x) - 0.001 and p.x <= max(p1.x, p2.x) + 0.001 and \
		   p.y >= min(p1.y, p2.y) - 0.001 and p.y <= max(p1.y, p2.y) + 0.001

func get_orthogonal_direction(p1: Vector2, p2: Vector2) -> Vector2:
	var dx = p2.x - p1.x
	var dy = p2.y - p1.y
	if abs(dx) > 0.1 and abs(dy) < 0.1:
		return Vector2(sign(dx), 0.0)
	elif abs(dy) > 0.1 and abs(dx) < 0.1:
		return Vector2(0.0, sign(dy))
	return Vector2.ZERO

func _print_points_debug(points: Array[Vector2]) -> void:
	var str = "当前点序列: ["
	for i in range(points.size()):
		if i > 0: str += ", "
		str += "(%.0f,%.0f)" % [points[i].x, points[i].y]
	str += "]"
	print(str)

func dir_to_str(dir: Vector2) -> String:
	if dir == Vector2.RIGHT: return "RIGHT"
	if dir == Vector2.LEFT:  return "LEFT"
	if dir == Vector2.UP:    return "UP"
	if dir == Vector2.DOWN:  return "DOWN"
	return "UNKNOWN"

func rebuild_pipes() -> void:
	if has_node("PipeBuilder"):
		var pb = $PipeBuilder
		if pb.has_method("build_pipes_from_lines"):
			pb.build_pipes_from_lines(line_data_list)
		elif pb.has_method("build_pipes"):
			pb.build_pipes()

func get_all_points() -> Array[Vector2]:
	var all_points: Array[Vector2] = []
	for line_data in line_data_list:
		for p in line_data.points:
			all_points.append(p)
	return all_points

func get_line_data_list() -> Array[Dictionary]:
	return line_data_list
