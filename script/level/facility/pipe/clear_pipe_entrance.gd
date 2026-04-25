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
var overlap_player_meta_cnt : int = 0

# 记录已进入该入口的实体 ID，避免重复触发
var overlapped_ids : Dictionary = {}

func _ready() -> void:
	clear_pipe_set = get_node(path_to_clear_pipe_set)
	body_entered.connect(_on_body_entered)
	turning_area = get_node(path_to_turning)
	if process_mode == ProcessMode.PROCESS_MODE_DISABLED or not visible:
		queue_free()

func _physics_process(_delta: float) -> void:
	var bodies = get_overlapping_bodies()
	position = position  # 强制刷新碰撞检测（Godot 特性）
	if bodies.size() > 0:
		set_meta("overlapping_with_block", true)
	else:
		if has_meta("overlapping_with_block"):
			remove_meta("overlapping_with_block")

	# 清理已离开的实体记录
	var current_ids = {}
	for body in bodies:
		if body.is_in_group("player") or body.has_meta("basic_movement"):
			current_ids[body.get_instance_id()] = true

		# 透明水管的连接
		if body.has_meta("clear_pipe_turning_area"):
			var turning = body.get_meta("clear_pipe_turning_area") as ClearPipeTurningArea2D
			var t_dir = turning.direction
			var e_dir = entrance_direction
			if t_dir == ClearPipeSet.Direction.LEFT and e_dir == Direction.LEFT \
			or t_dir == ClearPipeSet.Direction.RIGHT and e_dir == Direction.RIGHT \
			or t_dir == ClearPipeSet.Direction.UP and e_dir == Direction.UP \
			or t_dir == ClearPipeSet.Direction.DOWN and e_dir == Direction.DOWN:
				queue_free()

	# 移除已不在区域内的实体记录
	for id in overlapped_ids.keys():
		if not current_ids.has(id):
			# 检查物体是否在管道内，如果是则不清除记录
			var body = instance_from_id(id)
			if body:
				if body.is_in_group("player") and body.has_meta("is_in_pipe"):
					continue
				elif body.has_meta("basic_movement"):
					var basic_movement = body.get_meta("basic_movement")
					if basic_movement.is_in_pipe:
						continue
			overlapped_ids.erase(id)

	# 针对玩家的 overlap meta 处理
	if has_meta("overlapped_with_player"):
		if overlap_player_meta_cnt < 5:
			overlap_player_meta_cnt += 1
		else:
			# 检查玩家是否还在管道内，如果是则不清除
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_meta("is_in_pipe"):
				overlap_player_meta_cnt = 0  # 重置计数器，继续等待
			else:
				remove_meta("overlapped_with_player")



func _on_body_entered(body : Node2D) -> void:
	if not (body.is_in_group("player") or body.has_meta("basic_movement")):
		return

	var id = body.get_instance_id()
	if overlapped_ids.has(id):
		return
	overlapped_ids[id] = true

	# 告诉 body 它应该从哪个方向进入管道（实际由 body 自己处理）
	var direction
	match clear_pipe_set.direction:
		ClearPipeSet.Direction.LEFT:
			direction = PlayerMovement.PipeMoveDirection.RIGHT
		ClearPipeSet.Direction.RIGHT:
			direction = PlayerMovement.PipeMoveDirection.LEFT
		ClearPipeSet.Direction.UP:
			direction = PlayerMovement.PipeMoveDirection.DOWN
		ClearPipeSet.Direction.DOWN:
			direction = PlayerMovement.PipeMoveDirection.UP
	body.set_meta("clear_pipe_direction", direction)

func is_overlapped_with(body: Node2D) -> bool:
	return overlapped_ids.has(body.get_instance_id())

func clear_overlapped(body: Node2D) -> void:
	overlapped_ids.erase(body.get_instance_id())