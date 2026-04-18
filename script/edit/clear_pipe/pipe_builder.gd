extends Node2D

# 导出零件场景
@export var cap_up_scene: PackedScene          # 上开口
@export var cap_down_scene: PackedScene        # 下开口
@export var cap_left_scene: PackedScene        # 左开口
@export var cap_right_scene: PackedScene       # 右开口

@export var straight_horizontal_scene: PackedScene   # 水平直管 32x64
@export var straight_vertical_scene: PackedScene     # 垂直直管 64x32

# 拐角场景导出保留，但当前逻辑不使用
@export var corner_ur_scene: PackedScene
@export var corner_ul_scene: PackedScene
@export var corner_dr_scene: PackedScene
@export var corner_dl_scene: PackedScene

const STEP: float = 32.0
const CORNER_STEP: float = 64.0   # 拐角步长，暂时忽略

func build_pipes() -> void:
	# 清除旧零件
	for child in get_children():
		child.queue_free()

	var parent = get_parent()
	if not parent or not parent.has_method("get"):
		printerr("父节点无效或没有 get 方法")
		return

	var pts_var = parent.get("points")
	if not (pts_var is Array):
		printerr("父节点 points 不是数组")
		return

	var pts: Array[Vector2] = []
	for p in pts_var:
		if p is Vector2:
			pts.append(p)

	if pts.size() < 2:
		printerr("点数不足，无法生成管道")
		return

	# ----- 调试输出：所有点坐标 -----
	print("========== Points 列表 ==========")
	for i in pts.size():
		print("  point[%d] = (%.1f, %.1f)" % [i, pts[i].x, pts[i].y])
	print("=================================")

	# 统计直线段数量（用于确定第一个和最后一个有效直线段）
	var straight_segments: Array[Dictionary] = []   # 存储 {start, end, center, dir, index}
	for i in range(pts.size() - 1):
		var start := pts[i]
		var end := pts[i + 1]
		var dir := get_orthogonal_direction(start, end)
		if dir == Vector2.ZERO:
			printerr("线段 %d 不是正交方向" % i)
			continue
		var dist := start.distance_to(end)
		if is_equal_approx(dist, STEP):
			var center := (start + end) * 0.5
			straight_segments.append({
				"index": i,
				"start": start,
				"end": end,
				"center": center,
				"dir": dir
			})
		elif is_equal_approx(dist, CORNER_STEP):
			print("跳过拐角段 %d，距离64px，暂不生成零件" % i)
		else:
			printerr("线段 %d 距离 %.2f 不是标准步长 (32 或 64)" % [i, dist])

	# 生成零件
	var generated_count := 0
	var total_straight := straight_segments.size()

	if total_straight == 0:
		print("没有可生成的直线段")
		return

	print("共有 %d 个直线段，首尾将替换为开口零件" % total_straight)

	for idx in range(total_straight):
		var seg = straight_segments[idx]
		var center: Vector2 = seg.center
		var dir: Vector2 = seg.dir
		var is_first := (idx == 0)
		var is_last := (idx == total_straight - 1)

		if is_first or is_last:
			# 生成开口零件，方向朝外
			var outward_dir: Vector2
			if is_first:
				# 起点开口：方向为从第一个点指向第二个点的反方向（即朝外）
				outward_dir = -dir
			else:
				# 终点开口：方向与最后一段方向相同（朝外）
				outward_dir = dir
			place_cap(center, outward_dir)
			generated_count += 1
			print("生成开口零件，中心 = (%.1f, %.1f)，朝向外侧 = %s" % [center.x, center.y, dir_to_str(outward_dir)])
		else:
			# 中间直线零件
			place_straight(center, dir)
			generated_count += 1
			var type_name := "水平直管" if (dir == Vector2.RIGHT or dir == Vector2.LEFT) else "垂直直管"
			print("生成 %s，中心 = (%.1f, %.1f)，方向 = %s" % [type_name, center.x, center.y, dir_to_str(dir)])

	print("共生成 %d 个管道零件（含开口）" % generated_count)


func get_orthogonal_direction(p1: Vector2, p2: Vector2) -> Vector2:
	var dx := p2.x - p1.x
	var dy := p2.y - p1.y
	if abs(dx) > 0.1 and abs(dy) < 0.1:
		return Vector2(sign(dx), 0.0)
	elif abs(dy) > 0.1 and abs(dx) < 0.1:
		return Vector2(0.0, sign(dy))
	return Vector2.ZERO


func place_straight(center: Vector2, dir: Vector2) -> void:
	var scene: PackedScene
	var rot: float = 0.0

	if dir == Vector2.RIGHT:
		scene = straight_horizontal_scene
		rot = 0.0
	elif dir == Vector2.LEFT:
		scene = straight_horizontal_scene
		rot = 180.0
	elif dir == Vector2.UP:
		scene = straight_vertical_scene
		rot = 0.0   # 根据实际资源朝向调整
	elif dir == Vector2.DOWN:
		scene = straight_vertical_scene
		rot = 0.0
	else:
		return

	if scene:
		var inst := scene.instantiate()
		inst.position = center
		inst.rotation_degrees = rot
		add_child(inst)
	else:
		printerr("缺少直线零件场景资源")


func place_cap(center: Vector2, outward_dir: Vector2) -> void:
	var scene: PackedScene
	var rot: float = 0.0

	# 开口零件的旋转可能需要调整，这里假设默认开口方向为朝右（可根据资源修改）
	if outward_dir == Vector2.RIGHT:
		scene = cap_right_scene
		rot = 0.0
	elif outward_dir == Vector2.LEFT:
		scene = cap_left_scene
		rot = 0.0
	elif outward_dir == Vector2.UP:
		scene = cap_up_scene
		rot = 0.0
	elif outward_dir == Vector2.DOWN:
		scene = cap_down_scene
		rot = 0.0
	else:
		return

	if scene:
		var inst := scene.instantiate()
		inst.position = center
		inst.rotation_degrees = rot
		add_child(inst)
	else:
		printerr("缺少开口零件场景资源（%s）" % dir_to_str(outward_dir))


func dir_to_str(dir: Vector2) -> String:
	if dir == Vector2.RIGHT: return "RIGHT"
	if dir == Vector2.LEFT:  return "LEFT"
	if dir == Vector2.UP:    return "UP"
	if dir == Vector2.DOWN:  return "DOWN"
	return "UNKNOWN"