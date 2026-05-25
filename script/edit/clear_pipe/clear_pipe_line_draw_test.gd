extends Node2D

@export var debug_mode: bool = false

signal pipe_moved
signal pipe_drawn

const STEP: float = 32.0
const CORNER_STEP: float = 64.0
const LINE_WIDTH: float = 62.0
const HANDLER_SCENE = preload("res://object/edit/clear_pipe/clear_pipe_node_handler.tscn")

var line_data_list: Array[Dictionary] = []
var current_line_index: int = -1
var drawing: bool = false
var editing_line_index: int = -1
var editing_from_head: bool = false
var dragging_line_index: int = -1
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_original_points: Array[Vector2] = []

var drawing_enabled: bool = false

var handlers_node: Node2D
var lines_node: Node2D

func _ready() -> void:
	handlers_node = Node2D.new()
	handlers_node.name = "Handlers"
	handlers_node.process_mode = Node.PROCESS_MODE_DISABLED
	handlers_node.visible = drawing_enabled
	add_child(handlers_node)

	lines_node = Node2D.new()
	lines_node.name = "Lines"
	add_child(lines_node)

func _input(event: InputEvent) -> void:
	if not drawing_enabled:
		return

	var local_pos: Vector2

	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var viewport = get_viewport()
		if viewport:
			local_pos = to_local(viewport.get_canvas_transform().affine_inverse() * event.position)
		else:
			local_pos = get_local_mouse_position()

	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		var viewport = get_viewport()
		if viewport:
			local_pos = to_local(viewport.get_canvas_transform().affine_inverse() * event.position)
		else:
			local_pos = to_local(event.position)

	else:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var handler = get_handler_at_position(local_pos)
				if handler:
					if not drawing and dragging_line_index < 0:
						_on_handler_pressed(handler)
				else:
					var clicked_line = get_line_at_position(local_pos)
					if clicked_line >= 0:
						start_dragging_line(clicked_line, local_pos)
					else:
						start_drawing(local_pos)
			else:
				print("_input: mouse release, dragging=", dragging_line_index, " drawing=", drawing)
				if dragging_line_index >= 0:
					finish_dragging()
				if drawing:
					stop_drawing()

	elif event is InputEventMouseMotion:
		if dragging_line_index >= 0:
			update_dragging(local_pos)
		elif drawing:
			update_drawing(local_pos)

	elif event is InputEventScreenTouch:
		if event.pressed:
			var handler = get_handler_at_position(local_pos)
			if handler:
				if not drawing and dragging_line_index < 0:
					_on_handler_pressed(handler)
			else:
				var clicked_line = get_line_at_position(local_pos)
				if clicked_line >= 0:
					start_dragging_line(clicked_line, local_pos)
				else:
					start_drawing(local_pos)
		else:
			if dragging_line_index >= 0:
				finish_dragging()
			if drawing:
				stop_drawing()

	elif event is InputEventScreenDrag:
		if dragging_line_index >= 0:
			update_dragging(local_pos)
		elif drawing:
			update_drawing(local_pos)

func _screen_to_local(screen_pos: Vector2) -> Vector2:
	var viewport = get_viewport()
	if viewport:
		return to_local(viewport.get_canvas_transform().affine_inverse() * screen_pos)
	return to_local(screen_pos)

func get_handler_at_position(pos: Vector2) -> Node2D:
	if not handlers_node:
		return null
	var closest: Node2D = null
	var closest_dist: float = 22.0 * 22.0
	for handler in handlers_node.get_children():
		var dist = handler.position.distance_squared_to(pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = handler
	return closest

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
		return

	line_data.points = new_points
	line_data.line.points = new_points
	update_handlers_for_line(dragging_line_index)
	
	emit_signal("pipe_moved")

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

func can_draw_in_direction_from_head(line_idx: int, from_pos: Vector2, direction: Vector2) -> bool:
	var line_data = line_data_list[line_idx]
	var points = line_data.points

	if points.size() >= 2:
		var first_dir = get_orthogonal_direction(points[0], points[1])
		if first_dir != Vector2.ZERO:
			if direction == first_dir:
				return true
			var is_turn = (direction != -first_dir)
			var step = CORNER_STEP if is_turn else STEP
			var candidate = from_pos + direction * step
			if not can_add_point_at_head(points, candidate, line_idx):
				return false
			if would_overlap_visually_at_head(points, candidate):
				return false
			if would_overlap_other_lines_at_head(line_idx, points, candidate):
				return false
			return true

	var candidate = from_pos + direction * STEP
	if would_overlap_other_lines_at_head(line_idx, points, candidate):
		return false
	return true

func can_draw_in_direction(line_idx: int, from_pos: Vector2, direction: Vector2) -> bool:
	var line_data = line_data_list[line_idx]
	var points = line_data.points

	if points.size() >= 2:
		var last_dir = get_orthogonal_direction(points[-2], points[-1])
		if last_dir != Vector2.ZERO:
			if direction == -last_dir:
				return true
			var is_turn = (direction != last_dir)
			if is_turn and points.size() == 2:
				var straight_count = count_consecutive_same_direction(points, last_dir)
				if straight_count < 2:
					return false
			var step = CORNER_STEP if is_turn else STEP
			var candidate = from_pos + direction * step
			if not can_add_point(points, candidate, line_idx):
				return false
			if would_overlap_visually(points, candidate):
				return false
			if would_overlap_other_lines(line_idx, points, candidate):
				return false
			return true

	var candidate = from_pos + direction * STEP
	if would_overlap_other_lines(line_idx, points, candidate):
		return false
	return true
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
				return true
	elif not a_horizontal and not b_horizontal:
		var x_diff = abs(a1.x - b1.x)
		if x_diff < LINE_WIDTH:
			var a_min_y = min(a1.y, a2.y)
			var a_max_y = max(a1.y, a2.y)
			var b_min_y = min(b1.y, b2.y)
			var b_max_y = max(b1.y, b2.y)
			if not (a_max_y < b_min_y or a_min_y > b_max_y):
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
				return true

	return false

func start_drawing(pos: Vector2) -> void:
	var snapped = snap_to_grid(pos)

	if is_point_on_any_line(snapped):
		return

	var new_line_data = create_new_line(snapped)
	line_data_list.append(new_line_data)
	current_line_index = line_data_list.size() - 1

	var end_handler = create_handler(snapped, current_line_index, true)
	end_handler.set_held(true)
	line_data_list[current_line_index].end_handler = end_handler
	update_handler_directions(current_line_index)

	drawing = true

func create_new_line(start_pos: Vector2) -> Dictionary:
	var line = Line2D.new()
	line.width = LINE_WIDTH
	line.default_color = Color(1, 1, 1, 0.1)
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
	if not drawing_enabled:
		return
	if drawing or dragging_line_index >= 0:
		return
	editing_line_index = handler.line_index
	editing_from_head = not handler.is_tail
	handler.set_held(true)
	drawing = true

func stop_drawing() -> void:
	if not drawing:
		return

	print("stop_drawing: called, drawing=", drawing)
	drawing = false
	print("stop_drawing: drawing set to false, active_idx=", editing_line_index if editing_line_index >= 0 else current_line_index)

	var active_idx = editing_line_index if editing_line_index >= 0 else current_line_index

	if active_idx >= 0 and active_idx < line_data_list.size():
		var line_data = line_data_list[active_idx]
		var points = line_data.points

		if debug_mode:
			var pts_str = ""
			for p in points:
				pts_str += "(" + str(p.x) + ", " + str(p.y) + ") "
			print("[STOP] points: ", pts_str)

		if points.size() < 3:
			remove_line(active_idx)
		else:
			if editing_from_head and line_data.start_handler:
				line_data.start_handler.set_held(false)
				line_data.start_handler.position = points[0]
			elif line_data.end_handler:
				line_data.end_handler.set_held(false)
				line_data.end_handler.position = points[points.size() - 1]
			update_handler_directions(active_idx)

			rebuild_pipes()

	current_line_index = -1
	editing_line_index = -1
	editing_from_head = false

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

	if points.is_empty():
		return

	if editing_from_head:
		update_drawing_from_head(active_idx, line_data, points, current_pos)
	else:
		update_drawing_from_tail(active_idx, line_data, points, current_pos)

func update_drawing_from_head(active_idx: int, line_data: Dictionary, points: Array[Vector2], current_pos: Vector2) -> void:
	var first_point: Vector2 = points[0]
	var first_direction: Vector2 = line_data.get("first_direction", Vector2.ZERO)

	if points.size() >= 2:
		var second = points[1]
		var vec_to_second = second - first_point
		if abs(vec_to_second.x) > 0.1:
			first_direction = Vector2(sign(vec_to_second.x), 0.0)
		elif abs(vec_to_second.y) > 0.1:
			first_direction = Vector2(0.0, sign(vec_to_second.y))
		line_data.first_direction = first_direction

	var snapped = snap_to_grid(current_pos)
	var diff = snapped - first_point

	var move_dir = Vector2.ZERO
	if abs(diff.x) > abs(diff.y):
		move_dir = Vector2(sign(diff.x), 0.0)
	else:
		move_dir = Vector2(0.0, sign(diff.y))

	if move_dir == Vector2.ZERO:
		return

	var is_reverse = false
	if points.size() >= 2:
		var second = points[1]
		var vec_to_second = second - first_point
		var forward_dir = Vector2.ZERO
		if abs(vec_to_second.x) > 0.1:
			forward_dir = Vector2(sign(vec_to_second.x), 0.0)
		elif abs(vec_to_second.y) > 0.1:
			forward_dir = Vector2(0.0, sign(vec_to_second.y))
		if forward_dir != Vector2.ZERO and move_dir == forward_dir:
			is_reverse = true

	if is_reverse:
		var axis_dist = abs(diff.x) if move_dir.x != 0 else abs(diff.y)
		if axis_dist >= STEP:
			var candidate = first_point + move_dir * STEP
			var second_point = points[1]
			if candidate.distance_squared_to(second_point) <= STEP * STEP + 1.0:
				points.pop_front()
				if points.size() > 0:
						line_data.first_direction = Vector2.ZERO
						update_line_and_handlers(active_idx)
						# Emit signal when pipe is drawn to play sound effect
						emit_signal("pipe_drawn")
					# Emit signal when pipe is drawn to play sound effect
						emit_signal("pipe_drawn")
				else:
					points.push_front(candidate)
					line_data.first_direction = Vector2.ZERO
					update_line_and_handlers(active_idx)
					# Emit signal when pipe is drawn to play sound effect
					emit_signal("pipe_drawn")
			else:
				first_point = candidate
		return

	var is_extending = (first_direction != Vector2.ZERO and move_dir == -first_direction)

	var direction_changed = false
	if first_direction != Vector2.ZERO and move_dir != Vector2.ZERO:
		if move_dir != first_direction and move_dir != -first_direction:
			direction_changed = true

	var required_step = STEP
	if direction_changed:
		required_step = CORNER_STEP

	var axis_dist = abs(diff.x) if move_dir.x != 0 else abs(diff.y)
	if axis_dist < required_step:
		return

	var candidate = first_point + move_dir * required_step

	if can_add_point_at_head(points, candidate, active_idx) and not would_overlap_visually_at_head(points, candidate) and not would_overlap_other_lines_at_head(active_idx, points, candidate):
		points.push_front(candidate)
		line_data.first_direction = -move_dir
		update_line_and_handlers(active_idx)
		
		# Emit signal when pipe is drawn to play sound effect
		emit_signal("pipe_drawn")

func update_drawing_from_tail(active_idx: int, line_data: Dictionary, points: Array[Vector2], current_pos: Vector2) -> void:
	var last_point: Vector2 = points.back() if points.size() > 0 else Vector2.ZERO
	var last_direction: Vector2 = line_data.last_direction

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
					# Emit signal when pipe is drawn to play sound effect
					emit_signal("pipe_drawn")
				else:
					points.append(candidate)
					line_data.last_direction = Vector2.ZERO
					update_line_and_handlers(active_idx)
					# Emit signal when pipe is drawn to play sound effect
					emit_signal("pipe_drawn")
			else:
				last_point = candidate
		return

	var direction_changed = (last_direction != Vector2.ZERO and move_dir != last_direction)

	if direction_changed and points.size() == 2:
		var straight_count = count_consecutive_same_direction(points, last_direction)
		if straight_count < 2:
			return

	var required_step = CORNER_STEP if direction_changed else STEP
	var axis_dist = abs(diff.x) if move_dir.x != 0 else abs(diff.y)
	if axis_dist < required_step:
		return

	var candidate = last_point + move_dir * required_step

	if can_add_point(points, candidate, active_idx) and not would_overlap_visually(points, candidate) and not would_overlap_other_lines(active_idx, points, candidate):
		# When turning at the tail, remove the point before the corner to
		# avoid an extra short segment that creates a visual gap.
		if direction_changed and points.size() >= 3:
			var prev_seg_dir = get_orthogonal_direction(points[-3], points[-2])
			if prev_seg_dir != Vector2.ZERO and prev_seg_dir == line_data.last_direction:
				var removed = points[-2]
				points.remove_at(points.size() - 2)
				if debug_mode:
					print("[FIX] removed point before corner: (", removed.x, ", ", removed.y, "), new points size=", points.size())

		points.append(candidate)
		line_data.last_direction = move_dir
		update_line_and_handlers(active_idx)
		
		# Emit signal when pipe is drawn to play sound effect
		emit_signal("pipe_drawn")

func update_line_and_handlers(line_idx: int) -> void:
	var line_data = line_data_list[line_idx]
	line_data.line.points = line_data.points

	var points = line_data.points
	if points.size() > 0:
		if line_data.start_handler:
			line_data.start_handler.position = points[0]
		if line_data.end_handler:
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
	var points = line_data.points
	if points.size() < 1:
		return

	if line_data.start_handler:
		var head_pos = points[0]
		var can_right = can_draw_in_direction_from_head(line_idx, head_pos, Vector2.RIGHT)
		var can_left = can_draw_in_direction_from_head(line_idx, head_pos, Vector2.LEFT)
		var can_up = can_draw_in_direction_from_head(line_idx, head_pos, Vector2.UP)
		var can_down = can_draw_in_direction_from_head(line_idx, head_pos, Vector2.DOWN)
		line_data.start_handler.set_draw_directions(can_right, can_left, can_up, can_down)

	if line_data.end_handler:
		var tail_pos = points[points.size() - 1]
		var can_right = can_draw_in_direction(line_idx, tail_pos, Vector2.RIGHT)
		var can_left = can_draw_in_direction(line_idx, tail_pos, Vector2.LEFT)
		var can_up = can_draw_in_direction(line_idx, tail_pos, Vector2.UP)
		var can_down = can_draw_in_direction(line_idx, tail_pos, Vector2.DOWN)
		line_data.end_handler.set_draw_directions(can_right, can_left, can_up, can_down)

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

func count_consecutive_same_direction_from_head(points: Array[Vector2], dir_to_check: Vector2) -> int:
	if dir_to_check == Vector2.ZERO or points.size() < 2:
		return 0
	var count = 0
	var i = 0
	while i < points.size() - 1:
		var p1 = points[i]
		var p2 = points[i + 1]
		var seg_dir = get_orthogonal_direction(p1, p2)
		if seg_dir == dir_to_check:
			count += 1
		else:
			break
		i += 1
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

	for i in range(line_data_list.size()):
		if i == exclude_idx:
			continue
		var other_points = line_data_list[i].points
		if other_points.size() < 2:
			continue
		if check_new_segment_overlap(seg_start, seg_end, other_points):
			return true
	return false

func check_new_segment_overlap(seg_start: Vector2, seg_end: Vector2, other_points: Array[Vector2]) -> bool:
	for j in range(other_points.size() - 1):
		var p1 = other_points[j]
		var p2 = other_points[j + 1]
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

func can_add_point_at_head(points: Array[Vector2], new_point: Vector2, exclude_line_idx: int) -> bool:
	if points.size() < 2:
		return true
	var seg_start = new_point
	var seg_end = points[0]
	for i in range(1, points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]
		if segments_intersect(p1, p2, seg_start, seg_end):
			return false
	return true

func would_overlap_visually_at_head(points: Array[Vector2], new_point: Vector2) -> bool:
	if points.size() < 2:
		return false
	var seg_start = new_point
	var seg_end = points[0]
	var is_horizontal = (seg_start.y == seg_end.y)
	var y_level = seg_start.y if is_horizontal else 0.0
	var x_level = seg_start.x if not is_horizontal else 0.0
	var x_min = min(seg_start.x, seg_end.x)
	var x_max = max(seg_start.x, seg_end.x)
	var y_min = min(seg_start.y, seg_end.y)
	var y_max = max(seg_start.y, seg_end.y)

	for i in range(1, points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]
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

func would_overlap_other_lines_at_head(exclude_idx: int, points: Array[Vector2], new_point: Vector2) -> bool:
	if points.size() < 1:
		return false

	var seg_start = new_point
	var seg_end = points[0]

	for i in range(line_data_list.size()):
		if i == exclude_idx:
			var other_points = line_data_list[i].points
			if other_points.size() >= 2:
				for j in range(1, other_points.size() - 1):
					var p1 = other_points[j]
					var p2 = other_points[j + 1]
					if segments_too_close(seg_start, seg_end, p1, p2):
						return true
			continue
		var other_points = line_data_list[i].points
		if other_points.size() < 2:
			continue
		if check_new_segment_overlap(seg_start, seg_end, other_points):
			return true
	return false

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

func get_pipe_line_data() -> Array:
	var data: Array = []
	for line_data in line_data_list:
		var line_points: Array = []
		for p in line_data.points:
			line_points.append({"x": p.x, "y": p.y})
		if line_points.size() >= 2:
			data.append({"points": line_points})
	return data

func load_from_pipe_line_data(data: Array) -> void:
	clear_all_lines()

	for line_entry in data:
		var pts_data = line_entry.get("points", [])
		var points: Array[Vector2] = []
		for p_dict in pts_data:
			points.append(Vector2(p_dict.get("x", 0), p_dict.get("y", 0)))

		if points.size() < 2:
			continue

		var line = Line2D.new()
		line.width = LINE_WIDTH
		line.default_color = Color(1, 1, 1, 0.1)
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		lines_node.add_child(line)
		line.points = points

		var last_direction = get_orthogonal_direction(points[-2], points[-1]) if points.size() >= 2 else Vector2.ZERO
		var start_handler = create_handler(points[0], line_data_list.size(), false)
		var end_handler = create_handler(points[points.size() - 1], line_data_list.size(), true)

		line_data_list.append({
			"line": line,
			"points": points,
			"last_direction": last_direction,
			"start_handler": start_handler,
			"end_handler": end_handler
		})

	for i in range(line_data_list.size()):
		update_handler_directions(i)

	rebuild_pipes()

func clear_all_lines() -> void:
	for line_data in line_data_list:
		if line_data.line:
			line_data.line.queue_free()
		if line_data.start_handler:
			line_data.start_handler.queue_free()
		if line_data.end_handler:
			line_data.end_handler.queue_free()
	line_data_list.clear()
	current_line_index = -1
	dragging_line_index = -1
	drawing = false

func erase_line_at_world_position(world_pos: Vector2) -> bool:
	var local_pos = to_local(world_pos)
	var line_idx = get_line_at_position(local_pos)
	if line_idx >= 0:
		remove_line(line_idx)
		rebuild_pipes()
		return true
	return false

func _process(_delta: float) -> void:
	if drawing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		print("_process: drawing but mouse released, force stop")
		stop_drawing()
	if debug_mode:
		queue_redraw()

func _draw() -> void:
	if not debug_mode:
		return
	for line_data in line_data_list:
		var points = line_data.points
		for p in points:
			draw_circle(p, 8.0, Color.RED)

func set_drawing_enabled(enabled: bool) -> void:
	drawing_enabled = enabled
	if not enabled:
		if drawing:
			stop_drawing()
		dragging_line_index = -1
		if handlers_node:
			handlers_node.process_mode = Node.PROCESS_MODE_DISABLED
			handlers_node.visible = false
	else:
		if handlers_node:
			handlers_node.process_mode = Node.PROCESS_MODE_INHERIT
			handlers_node.visible = true
