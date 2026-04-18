extends Node2D

@export var cap_up_scene: PackedScene
@export var cap_down_scene: PackedScene
@export var cap_left_scene: PackedScene
@export var cap_right_scene: PackedScene

@export var straight_horizontal_scene: PackedScene
@export var straight_vertical_scene: PackedScene

@export var corner_ur_scene: PackedScene   # 暂未使用
@export var corner_ul_scene: PackedScene
@export var corner_dr_scene: PackedScene
@export var corner_dl_scene: PackedScene

const STEP: float = 32.0
const CORNER_STEP: float = 64.0

func build_pipes() -> void:
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

	print("========== 生成管道，点数: %d ==========" % pts.size())
	for i in pts.size():
		print("  pts[%d] = (%.0f, %.0f)" % [i, pts[i].x, pts[i].y])

	# 第一步：收集所有原始线段信息
	var raw_segments: Array[Dictionary] = []
	for i in range(pts.size() - 1):
		var start = pts[i]
		var end = pts[i + 1]
		var dir = get_orthogonal_direction(start, end)
		if dir == Vector2.ZERO:
			continue
		var dist = start.distance_to(end)
		var center = (start + end) * 0.5
		var seg_type = "straight" if is_equal_approx(dist, STEP) else "corner"
		raw_segments.append({
			"index": i,
			"start": start, "end": end, "center": center, "dir": dir,
			"type": seg_type
		})

	# 第二步：强制修正直线段数量（处理拐角前后多一少一问题）
	var fixed_straights: Array[Dictionary] = []
	var i = 0
	while i < raw_segments.size():
		var seg = raw_segments[i]
		if seg.type == "straight":
			# 检查是否为拐角前的多余直线段
			# 条件：下一个线段是拐角，且当前线段与前一线段同向（形成连续直线）
			var next_is_corner = (i + 1 < raw_segments.size() and raw_segments[i + 1].type == "corner")
			var prev_same_dir = (fixed_straights.size() > 0 and fixed_straights[-1].dir == seg.dir)
			if next_is_corner and prev_same_dir:
				# 这是拐角前多余的直线段，跳过（不加入 fixed_straights）
				print("  ⚠️ 跳过拐角前多余直线段: 中心(%.0f,%.0f)" % [seg.center.x, seg.center.y])
				i += 1
				continue
			fixed_straights.append(seg)
		else:  # corner
			# 检查拐角后是否紧跟直线段，若无则补充一个
			var next_is_straight = (i + 1 < raw_segments.size() and raw_segments[i + 1].type == "straight")
			if not next_is_straight and i + 1 < raw_segments.size():
				# 拐角后缺少直线段，根据拐角后的下一个点方向补一个
				var next_seg = raw_segments[i + 1]  # 可能是另一个拐角或直线
				# 但通常拐角后应当紧跟直线，若无则生成一个虚拟直线段
				var next_start = seg.end
				var next_end = next_seg.start
				var virt_dir = get_orthogonal_direction(next_start, next_end)
				if virt_dir != Vector2.ZERO:
					var virt_center = (next_start + next_end) * 0.5
					var virt_seg = {
						"index": -1,
						"start": next_start, "end": next_end, "center": virt_center, "dir": virt_dir,
						"type": "straight", "virtual": true
					}
					fixed_straights.append(virt_seg)
					print("  ➕ 拐角后补充直线段: 中心(%.0f,%.0f)" % [virt_center.x, virt_center.y])
			i += 1
			continue
		i += 1

	# 如果没有任何直线段，退出
	if fixed_straights.is_empty():
		print("没有直线段可生成")
		return

	print("修正后直线段数量: %d" % fixed_straights.size())

	# 第三步：生成零件（首尾替换为开口）
	for idx in range(fixed_straights.size()):
		var seg = fixed_straights[idx]
		var center: Vector2 = seg.center
		var dir: Vector2 = seg.dir
		var is_first = (idx == 0)
		var is_last = (idx == fixed_straights.size() - 1)

		if is_first or is_last:
			var outward_dir = -dir if is_first else dir
			place_cap(center, outward_dir)
			print("  生成开口: 中心(%.0f,%.0f)，朝外 %s" % [center.x, center.y, dir_to_str(outward_dir)])
		else:
			place_straight(center, dir)
			var type_name = "水平" if (dir == Vector2.RIGHT or dir == Vector2.LEFT) else "垂直"
			print("  生成直管: 中心(%.0f,%.0f)，方向 %s" % [center.x, center.y, dir_to_str(dir)])

	print("生成完成，共 %d 个零件" % fixed_straights.size())


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


func dir_to_str(dir: Vector2) -> String:
	if dir == Vector2.RIGHT: return "RIGHT"
	if dir == Vector2.LEFT:  return "LEFT"
	if dir == Vector2.UP:    return "UP"
	if dir == Vector2.DOWN:  return "DOWN"
	return "UNKNOWN"