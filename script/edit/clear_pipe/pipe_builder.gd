extends Node2D

# 导出零件场景
@export var cap_up_scene: PackedScene
@export var cap_down_scene: PackedScene
@export var cap_left_scene: PackedScene
@export var cap_right_scene: PackedScene

@export var straight_horizontal_scene: PackedScene   # 水平直管 32x64
@export var straight_vertical_scene: PackedScene     # 垂直直管 64x32

@export var corner_ur_scene: PackedScene   # 拐角：上→右 / 右→上
@export var corner_ul_scene: PackedScene   # 上→左 / 左→上
@export var corner_dr_scene: PackedScene   # 下→右 / 右→下
@export var corner_dl_scene: PackedScene   # 下→左 / 左→下

const STEP: float = 32.0
const CORNER_STEP: float = 64.0

func build_pipes() -> void:
	# 清除旧零件
	for child in get_children():
		child.queue_free()

	var parent = get_parent()
	if not parent or not parent.has_method("get"):
		return
	var pts_var = parent.get("points")
	if not (pts_var is Array):
		return
	var pts: Array[Vector2] = []
	for p in pts_var:
		if p is Vector2:
			pts.append(p)

	if pts.size() < 2:
		return

	print("生成管道，点数：", pts.size())

	# 中间部分
	for i in range(pts.size() - 1):
		var start = pts[i]
		var end = pts[i + 1]
		var dir = get_orthogonal_direction(start, end)
		if dir == Vector2.ZERO:
			continue
		var dist = start.distance_to(end)

		if is_equal_approx(dist, STEP):
			place_straight((start + end) * 0.5, dir)
		elif is_equal_approx(dist, CORNER_STEP):
			var dir_in = Vector2.ZERO
			if i > 0:
				dir_in = get_orthogonal_direction(pts[i - 1], start)
			else:
				continue
			place_corner((start + end) * 0.5, dir_in, dir)

	# 两端开口
	var start_dir = get_orthogonal_direction(pts[1], pts[0])
	place_cap(pts[0], start_dir)
	var end_dir = get_orthogonal_direction(pts[-2], pts[-1])
	place_cap(pts[-1], end_dir)

func get_orthogonal_direction(p1: Vector2, p2: Vector2) -> Vector2:
	var dx = p2.x - p1.x
	var dy = p2.y - p1.y
	if abs(dx) > 0.1 and abs(dy) < 0.1:
		return Vector2(sign(dx), 0.0)
	elif abs(dy) > 0.1 and abs(dx) < 0.1:
		return Vector2(0.0, sign(dy))
	return Vector2.ZERO

func place_straight(center: Vector2, dir: Vector2):
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

func place_corner(center: Vector2, dir_in: Vector2, dir_out: Vector2):
	var combo = dir_to_str(dir_in) + "->" + dir_to_str(dir_out)
	var map = {
		"RIGHT->UP": [corner_ur_scene, 0.0],
		"UP->RIGHT": [corner_ur_scene, 0.0],
		"RIGHT->DOWN": [corner_dr_scene, 0.0],
		"DOWN->RIGHT": [corner_dr_scene, 0.0],
		"LEFT->UP": [corner_ul_scene, 0.0],
		"UP->LEFT": [corner_ul_scene, 0.0],
		"LEFT->DOWN": [corner_dl_scene, 0.0],
		"DOWN->LEFT": [corner_dl_scene, 0.0],
	}
	if combo in map:
		var entry = map[combo]
		if entry[0]:
			var inst = entry[0].instantiate()
			inst.position = center
			inst.rotation_degrees = entry[1]
			add_child(inst)
	else:
		print("未知拐角组合: ", combo)

func place_cap(point: Vector2, outward_dir: Vector2):
	var scene: PackedScene
	if outward_dir == Vector2.UP: scene = cap_up_scene
	elif outward_dir == Vector2.DOWN: scene = cap_down_scene
	elif outward_dir == Vector2.LEFT: scene = cap_left_scene
	elif outward_dir == Vector2.RIGHT: scene = cap_right_scene
	else: return
	if scene:
		var inst = scene.instantiate()
		inst.position = point
		add_child(inst)

func dir_to_str(dir: Vector2) -> String:
	if dir == Vector2.RIGHT: return "RIGHT"
	if dir == Vector2.LEFT:  return "LEFT"
	if dir == Vector2.UP:    return "UP"
	if dir == Vector2.DOWN:  return "DOWN"
	return "UNKNOWN"
