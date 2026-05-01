extends Node2D

@export var cap_up_scene: PackedScene
@export var cap_down_scene: PackedScene
@export var cap_left_scene: PackedScene
@export var cap_right_scene: PackedScene

@export var straight_horizontal_scene: PackedScene
@export var straight_vertical_scene: PackedScene

@export var corner_ur_scene: PackedScene
@export var corner_ul_scene: PackedScene
@export var corner_dr_scene: PackedScene
@export var corner_dl_scene: PackedScene

const STEP: float = 32.0
const CORNER_STEP: float = 64.0

func build_pipes() -> void:
	clear_all_pipes()
	
	var parent = get_parent()
	if not parent or not parent.has_method("get"):
		return
	
	var line_data_list = parent.get("line_data_list")
	if line_data_list is Array and line_data_list.size() > 0:
		build_pipes_from_lines(line_data_list)
		return
	
	var pts_var = parent.get("points")
	if pts_var is Array:
		build_single_line(pts_var)

func build_pipes_from_lines(line_data_list: Array) -> void:
	clear_all_pipes()
	
	for line_idx in range(line_data_list.size()):
		var line_data = line_data_list[line_idx]
		var pts_var = line_data.get("points", [])
		
		var pts: Array[Vector2] = []
		for p in pts_var:
			if p is Vector2:
				pts.append(p)
		
		if pts.size() < 2:
			continue
		
		build_line_pipes(pts, line_idx)

func build_single_line(pts_var: Array) -> void:
	clear_all_pipes()
	
	var pts: Array[Vector2] = []
	for p in pts_var:
		if p is Vector2:
			pts.append(p)
	
	if pts.size() < 2:
		return
	
	build_line_pipes(pts, 0)

func build_line_pipes(pts: Array[Vector2], line_idx: int) -> void:
	if pts.size() < 2:
		return

	for i in range(1, pts.size() - 1):
		var prev_dir = get_orthogonal_direction(pts[i-1], pts[i])
		var next_dir = get_orthogonal_direction(pts[i], pts[i+1])
		if prev_dir != Vector2.ZERO and next_dir != Vector2.ZERO and prev_dir != next_dir:
			place_corner(pts[i], prev_dir, next_dir)

	for i in range(pts.size() - 1):
		var start = pts[i]
		var end = pts[i + 1]
		var direction = get_orthogonal_direction(start, end)
		if direction == Vector2.ZERO:
			continue
		
		var center = (start + end) / 2.0
		
		var is_first_segment = (i == 0)
		var is_last_segment = (i == pts.size() - 2)
		
		var has_corner_after = false
		if i + 1 < pts.size() - 1:
			var next_dir = get_orthogonal_direction(pts[i+1], pts[i+2])
			if next_dir != Vector2.ZERO and next_dir != direction:
				has_corner_after = true
		
		var has_corner_before = false
		if i > 0:
			var prev_dir = get_orthogonal_direction(pts[i-1], pts[i])
			if prev_dir != Vector2.ZERO and prev_dir != direction:
				has_corner_before = true
		
		if has_corner_after:
			continue
		
		if has_corner_before:
			center = center + direction * (STEP / 2.0)
		
		if is_first_segment and is_last_segment:
			place_straight(center, direction)
		elif is_first_segment:
			place_cap(center, -direction)
		elif is_last_segment:
			place_cap(center, direction)
		else:
			place_straight(center, direction)

func clear_all_pipes() -> void:
	for child in get_children():
		child.queue_free()

func get_orthogonal_direction(p1: Vector2, p2: Vector2) -> Vector2:
	var dx = p2.x - p1.x
	var dy = p2.y - p1.y
	if abs(dx) > 0.1 and abs(dy) < 0.1:
		return Vector2(sign(dx), 0.0)
	elif abs(dy) > 0.1 and abs(dx) < 0.1:
		return Vector2(0.0, sign(dy))
	return Vector2.ZERO

func place_straight(center: Vector2, dir: Vector2) -> void:
	var scene: PackedScene
	var rot: float = 0.0
	if dir == Vector2.RIGHT:
		scene = straight_horizontal_scene; rot = 0.0
	elif dir == Vector2.LEFT:
		scene = straight_horizontal_scene; rot = 180.0
	elif dir == Vector2.UP:
		scene = straight_vertical_scene; rot = 0.0
	elif dir == Vector2.DOWN:
		scene = straight_vertical_scene; rot = 0.0
	else: return
	if scene:
		var inst = scene.instantiate()
		inst.position = center
		inst.rotation_degrees = rot
		add_child(inst)

func place_cap(center: Vector2, outward_dir: Vector2) -> void:
	var scene: PackedScene
	var rot: float = 0.0
	if outward_dir == Vector2.RIGHT:
		scene = cap_right_scene
	elif outward_dir == Vector2.LEFT:
		scene = cap_left_scene
	elif outward_dir == Vector2.UP:
		scene = cap_up_scene
	elif outward_dir == Vector2.DOWN:
		scene = cap_down_scene
	else: return
	if scene:
		var inst = scene.instantiate()
		inst.position = center
		inst.rotation_degrees = rot
		add_child(inst)

func place_corner(center: Vector2, incoming_dir: Vector2, outgoing_dir: Vector2) -> void:
	var scene: PackedScene
	var rot: float = 0.0
	
	var left_has_pipe = (incoming_dir == Vector2.RIGHT || outgoing_dir == Vector2.LEFT)
	var right_has_pipe = (incoming_dir == Vector2.LEFT || outgoing_dir == Vector2.RIGHT)
	var up_has_pipe = (incoming_dir == Vector2.DOWN || outgoing_dir == Vector2.UP)
	var down_has_pipe = (incoming_dir == Vector2.UP || outgoing_dir == Vector2.DOWN)
	
	if up_has_pipe && right_has_pipe:
		scene = corner_ur_scene
	elif up_has_pipe && left_has_pipe:
		scene = corner_ul_scene
	elif down_has_pipe && right_has_pipe:
		scene = corner_dr_scene
	elif down_has_pipe && left_has_pipe:
		scene = corner_dl_scene
	else:
		return
	
	if scene:
		var inst = scene.instantiate()
		inst.position = center
		inst.rotation_degrees = rot
		add_child(inst)

func dir_to_str(dir: Vector2) -> String:
	if dir == Vector2.RIGHT: return "RIGHT"
	if dir == Vector2.LEFT:  return "LEFT"
	if dir == Vector2.UP:    return "UP"
	if dir == Vector2.DOWN:  return "DOWN"
	return "UNKNOWN"
