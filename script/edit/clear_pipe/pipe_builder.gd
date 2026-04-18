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

	# 修复逻辑：每两个相邻点之间生成一个管道零件，正确处理半格偏移
	var fixed_straights: Array[Dictionary] = []
	var used_positions: Dictionary = {}
	
	for i in range(pts.size() - 1):
		var start = pts[i]
		var end = pts[i + 1]
		var direction = get_orthogonal_direction(start, end)
		if direction == Vector2.ZERO:
			continue
		
		# 计算两点之间的精确中点
		var exact_mid = (start + end) / 2.0
		
		# 计算两点之间的精确中点（不进行网格对齐）
		var exact_center = (start + end) / 2.0
		
		# 使用精确中点作为管道中心，允许半网格位置
		var final_center = exact_center
		
		# 使用四舍五入的坐标作为唯一标识（用于去重）
		var pos_key = str(Vector2(round(final_center.x / STEP) * STEP, round(final_center.y / STEP) * STEP))
		
		# 如果这个位置还没有管道，则添加
		if not used_positions.has(pos_key):
			used_positions[pos_key] = true
			fixed_straights.append({
				"index": i,
				"start": start,
				"end": end,
				"center": final_center,
				"dir": direction,
				"type": "straight"
			})
	
	# 如果需要在拐角后多生成一个部件，检测方向变化
	# 检测路径中的方向变化点
	var additional_parts: Array[Dictionary] = []
	for i in range(1, pts.size() - 1):
		var prev_direction = get_orthogonal_direction(pts[i-1], pts[i])
		var next_direction = get_orthogonal_direction(pts[i], pts[i+1])
		if prev_direction != Vector2.ZERO and next_direction != Vector2.ZERO and prev_direction != next_direction:
			# 发生方向变化，即拐角点
			# 在拐角点后（下一个方向）多生成一个管道部件
			var corner_pt = pts[i]
			var next_pt = pts[i+1]
			# 计算两点之间的精确中点（不进行网格对齐）
			var exact_center = (corner_pt + next_pt) / 2.0
			
			# 使用精确中点作为管道中心，允许半网格位置
			var aligned_additional = exact_center
			
			# 使用四舍五入的坐标作为唯一标识（用于去重）
			var pos_key = str(Vector2(round(aligned_additional.x / STEP) * STEP, round(aligned_additional.y / STEP) * STEP))
			
			# 只有当该位置未被占用时才添加额外部件
			if not used_positions.has(pos_key):
				used_positions[pos_key] = true
				additional_parts.append({
					"index": i,
					"start": corner_pt,
					"end": next_pt,
					"center": aligned_additional,
					"dir": next_direction,
					"type": "straight"
				})
				print("  ➕ 拐角后补充管道部件: 中心(%.0f,%.0f)" % [aligned_additional.x, aligned_additional.y])
	
	# 合并主要管道和额外管道
	for additional_part in additional_parts:
		fixed_straights.append(additional_part)
	
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