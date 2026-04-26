extends Node

class_name BasicMovement

signal crushed_at(crush_pos: Vector2)
signal pipe_entered
signal pipe_exited

@export var path_to_move_object: NodePath = ".."

@export var initially_face_to_player: bool = true
@export var speed_x: float = 60.0
@export var speed_y: float
@export var gravity: float = 650.0
@export var max_fall_speed: float = 999.0
@export var jump_speed: float
@export var edge_detect: bool = false

@export var overlap_turn : bool = true
@export var can_be_turn_overlap_detected : bool = true
@export var path_to_shape_cast: NodePath = "../BasicShapeCast2D"

@export_category("Clear Pipe")
@export var is_clear_pipe_allowed : bool = false
@export var is_clear_pipe_allowed_up : bool = false
@export var is_clear_pipe_allowed_down : bool = false
@export var is_clear_pipe_allowed_left : bool = true
@export var is_clear_pipe_allowed_right : bool = true

@export var path_to_ani: NodePath = "../AnimatedSprite2D"
@export var dust_creator_scene : PackedScene = preload("uid://bpywk88hnp1yw")

const FRAMERATE_ORIGIN: float = 50.0
const CRUSHED_FRAMES: int = 1

var move_object : CharacterBody2D
var player: CharacterBody2D
var shape_cast : ShapeCast2D
var overlap_turn_detect_objects: Array[Node2D] = []

var crushed_frame_counter: int = 0

var ani : AnimatedSprite2D
var is_in_pipe : bool = false
enum PipeMoveDirection {
	LEFT,
	RIGHT,
	UP,
	DOWN,
	ALIGN,
}
var pipe_moving_dir : PipeMoveDirection = PipeMoveDirection.ALIGN
var out_pipe_cooldown : int = 0          # 出管冷却，防止立即再次进入
var pipe_in_cooldown : int = 0           # 进管冷却，防止立即误判出口
var clear_pipe_blocked_counter : int = 0
var previous_speed_x : float = 0.0
var previous_speed_y : float = 0.0
var pipe_origin_collision_layer : int

# 用于转向对齐时的原始方向暂存
var is_origin_pipe_dir_set : bool = false
var origin_pipe_dir : PipeMoveDirection = PipeMoveDirection.ALIGN

func _ready() -> void:
	move_object = get_node(path_to_move_object) as CharacterBody2D
	player = get_tree().get_first_node_in_group("player") as Node2D
	var fc = func():
		player = get_tree().get_first_node_in_group("player") as Node2D
		if initially_face_to_player:
			set_movement_direction()
	fc.call_deferred()
	if overlap_turn or is_clear_pipe_allowed:
		shape_cast = get_node_or_null(path_to_shape_cast) as ShapeCast2D
		if not shape_cast:
			for child in move_object.get_children():
				if child is ShapeCast2D:
					shape_cast = child
					break
			if not shape_cast:
				push_error("BasicMovement: ShapeCast2D not found.")

	move_object.set_meta("basic_movement", self)

	ani = get_node_or_null(path_to_ani) as AnimatedSprite2D
	if not ani:
		for child in move_object.get_children():
			if child is AnimatedSprite2D:
				ani = child
				break
		if not ani:
			push_error("[%s] BasicMovement: AnimatedSprite2D not found." % move_object.name)
			
	if is_clear_pipe_allowed:
		var dusk_creator = dust_creator_scene.instantiate()
		dusk_creator.parent = move_object
		pipe_entered.connect(dusk_creator.explode)
		pipe_exited.connect(dusk_creator.explode)

func _physics_process(delta: float) -> void:
	# 更新冷却计时器
	if out_pipe_cooldown > 0:
		out_pipe_cooldown -= 1
	if pipe_in_cooldown > 0:
		pipe_in_cooldown -= 1

	# 管道检测（每帧执行，但内部会根据冷却和状态判断）
	pipe_detect()
	
	if pipe_check():
		# 转向检测必须在管道移动前执行
		move_object.scale = move_object.scale.move_toward(Vector2(0.4, 0.4), 0.3)
		clear_pipe_turning_detect()
		pipe_movement()

		# 安全检测：管道运动后如果没有与墙体（碰撞层第1位）/TileMap重叠，说明已脱离管道
		if pipe_in_cooldown <= 0:
			var query = PhysicsShapeQueryParameters2D.new()
			query.shape = shape_cast.shape
			query.transform = move_object.global_transform
			query.collision_mask = 1
			query.collide_with_bodies = true
			query.collide_with_areas = false
			query.exclude = [move_object.get_rid()]
			var block_results = move_object.get_world_2d().direct_space_state.intersect_shape(query)
			if block_results.is_empty():
				exit_pipe()
				move_object.force_update_transform()

		return
	move_object.scale = move_object.scale.move_toward(Vector2(1.0, 1.0), 0.3)

	if in_wall_process():
		return

	turn_detect()
	overlap_turn_detect()
	speed_x_process()
	speed_y_process(delta)
	set_jump_speed()
	apply_speed()
	move()

func on_screen_entered() -> void:
	set_movement_direction()

func turn_detect() -> void:
	if edge_detect and move_object.is_on_floor():
		var origin_position = move_object.position
		move_object.position += Vector2(33.0 * sign(speed_x), 0.0)
		move_object.force_update_transform()
		var collision = move_object.move_and_collide(Vector2.DOWN * 20.0, true, 0.05)
		if collision == null:
			speed_x *= -1.0
		move_object.position = origin_position
		move_object.force_update_transform()

func overlap_turn_detect() -> void:
	if not overlap_turn:
		return
	var results = ShapeCastQuery.shape_query(move_object, shape_cast)
	if results.size() <= 1:
		overlap_turn_detect_objects.clear()
		return
	for result in results:
		if not is_instance_valid(result):
			continue
		if result is ClearPipeEntrance:
			continue
		if result == move_object:
			continue
		if result.has_meta("basic_movement"):
			var other_basic_movement_node = result.get_meta("basic_movement") as BasicMovement
			if not is_instance_valid(other_basic_movement_node) or not other_basic_movement_node.can_be_turn_overlap_detected:
				continue
		if !(result in overlap_turn_detect_objects):
			overlap_turn_detect_objects.append(result)
			speed_x *= -1.0

func speed_x_process() -> void:
	if out_pipe_cooldown > 0:
		return
	if move_object.is_on_wall():
		speed_x *= -1.0

func speed_y_process(delta: float) -> void:
	if not move_object.is_on_floor():
		speed_y = clamp(speed_y + gravity * delta, -max_fall_speed, max_fall_speed)
	else:
		speed_y = 0.0

func apply_speed() -> void:
	move_object.velocity = Vector2(speed_x, speed_y)

func move() -> void:
	move_object.move_and_slide()

func set_movement_direction() -> void:
	if not initially_face_to_player:
		return
	if player != null:
		if move_object.position.x < player.position.x:
			speed_x = abs(speed_x)
		elif move_object.position.x > player.position.x:
			speed_x = -abs(speed_x)

func set_jump_speed() -> void:
	if move_object.is_on_floor():
		speed_y = min(0.0, jump_speed)

func in_wall_process() -> bool:
	if out_pipe_cooldown > 0:
		return false
	if move_object.move_and_collide(Vector2.ZERO, true, 0.08) != null:
		move_object.velocity = Vector2.ZERO
		crushed_frame_counter += 1
		if crushed_frame_counter >= CRUSHED_FRAMES:
			emit_signal("crushed_at", move_object.position)
			return true
		return false
	crushed_frame_counter = 0
	return false

func pipe_check() -> bool:
	if not is_clear_pipe_allowed:
		return false
	return is_in_pipe

func pipe_detect() -> void:
	if not is_clear_pipe_allowed:
		return
	if out_pipe_cooldown > 0:
		return

	var results = ShapeCastQuery.shape_query(move_object, shape_cast)
	for result in results:
		if not is_instance_valid(result) or not result is ClearPipeEntrance:
			continue
		if result == move_object:
			continue

		var entrance := result as ClearPipeEntrance

		# 已在管道内：处理出口检测和阻塞反转
		if is_in_pipe:
			# 进入冷却期间，忽略出口检测（防止碰撞箱未及时缩小导致的误判）
			if pipe_in_cooldown > 0:
				return

			if entrance.has_meta("overlapping_with_block"):
				clear_pipe_blocked_counter += 1
				match pipe_moving_dir:
					PipeMoveDirection.LEFT:
						pipe_moving_dir = PipeMoveDirection.RIGHT
					PipeMoveDirection.RIGHT:
						pipe_moving_dir = PipeMoveDirection.LEFT
					PipeMoveDirection.UP:
						pipe_moving_dir = PipeMoveDirection.DOWN
					PipeMoveDirection.DOWN:
						pipe_moving_dir = PipeMoveDirection.UP
				clear_turning_processed_for_reversal()
				return

			# 无阻挡，正常退出管道
			move_object.position = entrance.global_position
			exit_pipe()
			move_object.force_update_transform()
			'''
			match entrance.entrance_direction:
				ClearPipeEntrance.Direction.LEFT:
					speed_x = -abs(speed_x) if speed_x else -60
				ClearPipeEntrance.Direction.RIGHT:
					speed_x = abs(speed_x) if speed_x else 60
				ClearPipeEntrance.Direction.UP:
					speed_y = -abs(speed_y) if speed_y else -60
				ClearPipeEntrance.Direction.DOWN:
					speed_y = abs(speed_y) if speed_y else 60
			'''
			return

		# 不在管道内：检查进入条件
		var should_enter := false
		var move_dir = Vector2(speed_x, speed_y).normalized()
		match entrance.entrance_direction:
			ClearPipeEntrance.Direction.LEFT:
				if move_dir.x < 0 and is_clear_pipe_allowed_left:
					should_enter = true
			ClearPipeEntrance.Direction.RIGHT:
				if move_dir.x > 0 and is_clear_pipe_allowed_right:
					should_enter = true
			ClearPipeEntrance.Direction.UP:
				if move_object.is_on_ceiling() and is_clear_pipe_allowed_up:
					should_enter = true
			ClearPipeEntrance.Direction.DOWN:
				if move_object.is_on_floor() and is_clear_pipe_allowed_down:
					should_enter = true

		if not should_enter:
			continue

		# 进入管道
		var enter_dir: PipeMoveDirection
		match entrance.entrance_direction:
			ClearPipeEntrance.Direction.LEFT:
				enter_dir = PipeMoveDirection.LEFT
			ClearPipeEntrance.Direction.RIGHT:
				enter_dir = PipeMoveDirection.RIGHT
			ClearPipeEntrance.Direction.UP:
				enter_dir = PipeMoveDirection.UP
			ClearPipeEntrance.Direction.DOWN:
				enter_dir = PipeMoveDirection.DOWN

		enter_pipe(enter_dir)
		move_object.position = entrance.turning_area.global_position if is_instance_valid(entrance.turning_area) else entrance.global_position
		entrance.overlapped_ids[move_object.get_instance_id()] = true
		break

func enter_pipe(enter_direction: PipeMoveDirection) -> void:
	pipe_moving_dir = enter_direction
	is_in_pipe = true
	pipe_in_cooldown = 5               # 设置进管冷却，持续5帧，防止误判出口
	previous_speed_x = speed_x
	previous_speed_y = speed_y
	speed_x = 0.0
	speed_y = 0.0
	pipe_origin_collision_layer = move_object.collision_layer
	move_object.collision_layer = move_object.collision_layer & (1 << 4)
	move_object.force_update_transform()
	var pipe_move_vec : Vector2
	match enter_direction:
		PipeMoveDirection.LEFT:
			pipe_move_vec = Vector2(-1, 0)
		PipeMoveDirection.RIGHT:
			pipe_move_vec = Vector2(1, 0)
		PipeMoveDirection.UP:
			pipe_move_vec = Vector2(0, -1)
		PipeMoveDirection.DOWN:
			pipe_move_vec = Vector2(0, 1)
	move_object.position = move_object.position + pipe_move_vec * 16
	emit_signal("pipe_entered")

func exit_pipe() -> void:
	is_in_pipe = false
	out_pipe_cooldown = 10
	pipe_in_cooldown = 0                # 确保冷却重置
	clear_pipe_blocked_counter = 0

	speed_x = previous_speed_x
	speed_y = previous_speed_y

	move_object.collision_layer = pipe_origin_collision_layer

	# 清除所有 turning area 的 processed 标记
	var turnings = get_tree().get_nodes_in_group("clear_pipe_turning_area")
	for turning in turnings:
		if is_instance_valid(turning) and turning is ClearPipeTurningArea2D:
			turning.clear_processed(move_object)
	# 清除所有 entrance 的 overlapped 标记
	var entrances = get_tree().get_nodes_in_group("clear_pipe_entrance")
	for entrance in entrances:
		if is_instance_valid(entrance) and entrance is ClearPipeEntrance:
			entrance.clear_overlapped(move_object)

	for i in range(5):
		move_object.velocity = Vector2.ZERO
		move_object.move_and_slide()
		move_object.force_update_transform()

	pipe_moving_dir = PipeMoveDirection.ALIGN
	is_origin_pipe_dir_set = false
	emit_signal("pipe_exited")

func pipe_movement() -> void:
	var moving_speed : float = 4.0
	match pipe_moving_dir:
		PipeMoveDirection.LEFT:
			move_object.position = move_object.position + Vector2(-moving_speed, 0)
		PipeMoveDirection.RIGHT:
			move_object.position = move_object.position + Vector2(moving_speed, 0)
		PipeMoveDirection.UP:
			move_object.position = move_object.position + Vector2(0, -moving_speed)
		PipeMoveDirection.DOWN:
			move_object.position = move_object.position + Vector2(0, moving_speed)
		PipeMoveDirection.ALIGN:
			pass  # 对齐时由转向检测控制移动
	move_object.force_update_transform()

func clear_pipe_turning_detect() -> void:
	var results = ShapeCastQuery.shape_query(move_object, shape_cast)
	for result in results:
		if not is_instance_valid(result) or not result is ClearPipeTurningArea2D:
			continue
		var area := result as ClearPipeTurningArea2D

		# 已处理过的转向区域不再重复转向
		if area.is_processed(move_object):
			continue

		var target := area.global_position + Vector2(0, 8)
		var diff := target - move_object.global_position

		# 如果需要位置对齐
		if abs(diff.x) > 0.5 or abs(diff.y) > 0.5:
			if not is_origin_pipe_dir_set:
				origin_pipe_dir = pipe_moving_dir
				is_origin_pipe_dir_set = true
			pipe_moving_dir = PipeMoveDirection.ALIGN
			move_object.global_position = move_object.global_position.move_toward(target, 4.0)
			continue

		# 对齐完成，执行转向
		if is_origin_pipe_dir_set:
			pipe_moving_dir = origin_pipe_dir
			is_origin_pipe_dir_set = false

		match area.direction:
			ClearPipeSet.Direction.LEFT:
				if pipe_moving_dir != PipeMoveDirection.LEFT:
					pipe_moving_dir = PipeMoveDirection.RIGHT
			ClearPipeSet.Direction.RIGHT:
				if pipe_moving_dir != PipeMoveDirection.RIGHT:
					pipe_moving_dir = PipeMoveDirection.LEFT
			ClearPipeSet.Direction.UP:
				if pipe_moving_dir != PipeMoveDirection.UP:
					pipe_moving_dir = PipeMoveDirection.DOWN
			ClearPipeSet.Direction.DOWN:
				if pipe_moving_dir != PipeMoveDirection.DOWN:
					pipe_moving_dir = PipeMoveDirection.UP
			ClearPipeSet.Direction.LEFT_UP:
				if pipe_moving_dir == PipeMoveDirection.RIGHT:
					pipe_moving_dir = PipeMoveDirection.UP
				elif pipe_moving_dir == PipeMoveDirection.DOWN:
					pipe_moving_dir = PipeMoveDirection.LEFT
			ClearPipeSet.Direction.LEFT_DOWN:
				if pipe_moving_dir == PipeMoveDirection.RIGHT:
					pipe_moving_dir = PipeMoveDirection.DOWN
				elif pipe_moving_dir == PipeMoveDirection.UP:
					pipe_moving_dir = PipeMoveDirection.LEFT
			ClearPipeSet.Direction.RIGHT_UP:
				if pipe_moving_dir == PipeMoveDirection.LEFT:
					pipe_moving_dir = PipeMoveDirection.UP
				elif pipe_moving_dir == PipeMoveDirection.DOWN:
					pipe_moving_dir = PipeMoveDirection.RIGHT
			ClearPipeSet.Direction.RIGHT_DOWN:
				if pipe_moving_dir == PipeMoveDirection.LEFT:
					pipe_moving_dir = PipeMoveDirection.DOWN
				elif pipe_moving_dir == PipeMoveDirection.UP:
					pipe_moving_dir = PipeMoveDirection.RIGHT

		area.mark_processed(move_object)

func clear_turning_processed_for_reversal() -> void:
	var turnings = get_tree().get_nodes_in_group("clear_pipe_turning_area")
	for turning in turnings:
		if is_instance_valid(turning) and turning is ClearPipeTurningArea2D:
			turning.clear_processed(move_object)
