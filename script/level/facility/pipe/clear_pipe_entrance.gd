extends Area2D

class_name ClearPipeEntrance

@export var path_to_clear_pipe_set : NodePath = "../PipeDirectionSet"
@export var path_to_turning : NodePath = "../ClearPipeTurningArea2D"

enum Direction {
	LEFT,
	RIGHT,
	UP,
	DOWN,
}
@export var entrance_direction : Direction = Direction.LEFT

var clear_pipe_set : ClearPipeSet
var turning_area : Area2D
var entrance_shape : Shape2D
var overlap_player_meta_cnt : int = 0

# 记录已进入该入口的实体 ID，避免重复触发
var overlapped_ids : Dictionary = {}

func _ready() -> void:
	clear_pipe_set = get_node(path_to_clear_pipe_set)
	body_entered.connect(_on_body_entered)
	turning_area = get_node(path_to_turning)
	for child in get_children():
		if child is CollisionShape2D and child.shape:
			entrance_shape = child.shape
			break
	if process_mode == ProcessMode.PROCESS_MODE_DISABLED or not visible:
		queue_free()

func _physics_process(_delta: float) -> void:
	# 使用 intersect_shape 检测所有碰撞体（含 TileMap 瓦片）
	var has_block := false
	if entrance_shape:
		var query = PhysicsShapeQueryParameters2D.new()
		query.shape = entrance_shape
		query.transform = global_transform
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var results = get_world_2d().direct_space_state.intersect_shape(query)
		for result in results:
			var collider = result.get("collider")
			if is_instance_valid(collider) and not (collider.is_in_group("player") or collider.has_meta("basic_movement")):
				has_block = true
				break
	if has_block:
		set_meta("overlapping_with_block", true)
	else:
		if has_meta("overlapping_with_block"):
			remove_meta("overlapping_with_block")

	# 用 get_overlapping_bodies 追踪玩家/敌人实体
	var bodies = get_overlapping_bodies()

	# 清理已离开的实体记录
	var current_ids = {}
	for body in bodies:
		if body.is_in_group("player") or body.has_meta("basic_movement"):
			current_ids[body.get_instance_id()] = true

		# 透明水管的连接
		if body.has_meta("clear_pipe_turning_area"):
			var turning = body.get_meta("clear_pipe_turning_area")
			if is_instance_valid(turning):
				var cd = turning.direction
				var ed = entrance_direction
				if cd == ClearPipeSet.Direction.LEFT and ed == Direction.LEFT \
				or cd == ClearPipeSet.Direction.RIGHT and ed == Direction.RIGHT \
				or cd == ClearPipeSet.Direction.UP and ed == Direction.UP \
				or cd == ClearPipeSet.Direction.DOWN and ed == Direction.DOWN:
					queue_free()

	# 移除已不在区域内的实体记录
	for id in overlapped_ids.keys():
		if not current_ids.has(id):
			var body = instance_from_id(id)
			if is_instance_valid(body):
				if body.is_in_group("player") and body.has_meta("is_in_pipe"):
					continue
				elif body.has_meta("basic_movement"):
					var basic_movement = body.get_meta("basic_movement")
					if basic_movement.is_in_pipe:
						continue
			overlapped_ids.erase(id)

	# 针对玩家的 overlap meta 处理 — 无条件 5 帧后清除
	if has_meta("overlapped_with_player"):
		if overlap_player_meta_cnt < 5:
			overlap_player_meta_cnt += 1
		else:
			remove_meta("overlapped_with_player")



func _on_body_entered(body : Node2D) -> void:
	if not (body.is_in_group("player") or body.has_meta("basic_movement")):
		return

	var id = body.get_instance_id()
	if overlapped_ids.has(id):
		return
	overlapped_ids[id] = true

func is_overlapped_with(body: Node2D) -> bool:
	return overlapped_ids.has(body.get_instance_id())

func clear_overlapped(body: Node2D) -> void:
	overlapped_ids.erase(body.get_instance_id())
