extends Node

signal player_hurt
signal player_die
signal player_pipe_blocked

@export var player_movement : PlayerMovement
@export var player_suit : PlayerSuit
@export var player : CharacterBody2D
@export var cast : ShapeCast2D

var starman : bool
var pipe_get_close_timer : int = 0
var is_origin_pipe_dir_set : bool = false
var origin_player_pipe_dir : PlayerMovement.PipeMoveDirection
var clear_pipe_blocked_counter : int = 0

func _physics_process(_delta: float) -> void:
	var results = ShapeCastQuery.shape_query(player, cast)
	
	clear_pipe_turning_detect(results)

	# 检测水管口（入口和出口）
	pipe_detect(results)

	# 检测门
	door_detect(results)

	# 安全检测：管道内如果没有与墙体（碰撞层第1位）/TileMap重叠，说明已脱离管道
	if player_movement.is_in_pipe and player_movement.pipe_in_cooldown <= 0:
		var query = PhysicsShapeQueryParameters2D.new()
		query.shape = cast.shape
		query.transform = cast.global_transform
		query.collision_mask = 1
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [player.get_rid()]
		var block_results = player.get_world_2d().direct_space_state.intersect_shape(query)
		if block_results.is_empty():
			player_movement.exit_pipe()
			player.force_update_transform()

	# 传送时不处理交互
	if player_movement.is_in_transport:
		return

	# 获得道具
	bonus_detect(results)

	# 无敌星撞击敌人
	starman_detect(results)
		
	# 踩踏
	hurt_and_stompable_detect(results)

	# Overlap Switch Detect
	overlap_switch_detect(results)

	# 顶砖检测
	var origin_pos = cast.position
	# 这里不用到up_direction是因为cast是玩家的子节点
	cast.position += Vector2(0.0, -1.0)
	results = ShapeCastQuery.shape_query(player, cast)
	block_hit_detect(results)
	cast.position = origin_pos

	triangle_block_detect(results)
	
func hurt_and_stompable_detect(results : Array[Node2D]) -> void:
	for result in results:
		if not result.has_meta("interaction_with_player"):
			continue
		var interaction_with_player_node = result.get_meta("interaction_with_player") as InteractionWithPlayer
		if not interaction_with_player_node.interactable:
			continue
		# 在上方踩踏并且可以踩踏
		interaction_with_player_node.on_overlap(player)
		var up = player.up_direction
		if player.global_position.dot(up) > result.global_position.dot(up) - interaction_with_player_node.stomp_offset \
		and interaction_with_player_node.stompable:
			# 踩踏成功
			if (not is_starman()) or (is_starman() and interaction_with_player_node.starman_stompable):
				if interaction_with_player_node.return_stomp_speed_y:
					player_movement.speed_y = interaction_with_player_node.on_stomped(player)
					if player_movement.move_jump:
						player_movement.speed_y *= 1.2
				else:
					interaction_with_player_node.on_stomped(player)
		else:
			# 踩踏失败
			match interaction_with_player_node.hurt_type:
				InteractionWithPlayer.HurtType.HURT:
					emit_signal("player_hurt")
				InteractionWithPlayer.HurtType.DIE:
					emit_signal("player_die")
				InteractionWithPlayer.HurtType.NOTHING:
					pass

func bonus_detect(results : Array[Node2D]) -> void:
	for result in results:
		if not result.has_meta("bonus_set"):
			continue
		var bonus_set_node = result.get_meta("bonus_set") as BonusSet
		bonus_set_node.on_bonus_get(player)
		if player_suit.suit == PlayerSuit.SuitType.SMALL and bonus_set_node.bonus_type == BonusSet.BonusType.MUSHROOM:
			player_suit.suit = PlayerSuit.SuitType.SUPER
		if bonus_set_node.bonus_type == BonusSet.BonusType.FIRE_FLOWER:
			player_suit.suit = PlayerSuit.SuitType.POWERED
			player_suit.power = PlayerSuit.PowerupType.FIREBALL
		if bonus_set_node.bonus_type == BonusSet.BonusType.BEETROOT:
			player_suit.suit = PlayerSuit.SuitType.POWERED
			player_suit.power = PlayerSuit.PowerupType.BEETROOT
		if bonus_set_node.bonus_type == BonusSet.BonusType.LUI:
			player_suit.suit = PlayerSuit.SuitType.POWERED
			player_suit.power = PlayerSuit.PowerupType.LUI
		if bonus_set_node.bonus_type == BonusSet.BonusType.BIG:
			player_suit.suit = PlayerSuit.SuitType.POWERED
			player_suit.power = PlayerSuit.PowerupType.BIG
		if bonus_set_node.bonus_type == BonusSet.BonusType.BEE:
			player_suit.suit = PlayerSuit.SuitType.POWERED
			player_suit.power = PlayerSuit.PowerupType.BEE
		if bonus_set_node.bonus_type == BonusSet.BonusType.CLOUD:
			player_suit.suit = PlayerSuit.SuitType.POWERED
			player_suit.power = PlayerSuit.PowerupType.CLOUD
		if bonus_set_node.bonus_type == BonusSet.BonusType.STAR:
			player_suit.starman_start()

func starman_detect(results : Array[Node2D]) -> bool:
	starman = is_starman()
	if not starman:
		return false
	for result in results:
		if not result.has_meta("interaction_with_star"):
			continue
		var interaction_with_star_node = result.get_meta("interaction_with_star") as InteractionWithStar
		if not interaction_with_star_node.is_hittable:
			continue
		interaction_with_star_node.on_star_hit(player.position)
	return true
		
func is_starman() -> bool:
	return player_suit.is_starman

func overlap_switch_detect(results : Array[Node2D]) -> void:
	for result in results:
		if not result is SwitchBlock:
			continue
		result.set_meta("overlapped_with_player", true)

func block_hit_detect(results : Array[Node2D]) -> void:
	#if not player.is_on_ceiling():
	#	return
	#print("block_hit_detect reuslts: ", results)

	for result in results:
		if not result.has_meta("interaction_with_block"):
			continue
		var block_hit_node = result.get_meta("interaction_with_block") as BlockHit
		
		# 大马里奥特殊处理
		if player_suit.suit == PlayerSuit.SuitType.POWERED \
		and player_suit.power == PlayerSuit.PowerupType.BIG \
		and not block_hit_node.hidden:
			continue

		if not block_hit_node.hidden and not player.is_on_ceiling():
			continue
		if block_hit_node.hidden:
			if player_movement.speed_y >= 0.0:
				continue
			if not player.is_on_wall() and not player.is_on_ceiling():
				continue
		# 服了这神秘物理引擎隐藏砖单向碰撞只能这样特殊处理
		if block_hit_node.hidden and player.is_on_wall():
			player_movement.speed_y = 0.0
		block_hit_node.on_block_hit(player)
		
		
		if player_suit.suit == PlayerSuit.SuitType.POWERED \
		and player_suit.power == PlayerSuit.PowerupType.BIG:
			player_movement.break_tile_cd_ceil = true
			for i in range(6):
				await get_tree().physics_frame
				if player_movement.speed_y > 0.0:
					player_movement.break_tile_cd_ceil = false
					break;
		

func pipe_detect(results : Array[Node2D]) -> void:
	if player_movement.out_pipe_cooldown > 0:
		return
	for result in results:
		if not is_instance_valid(result) or not result is ClearPipeEntrance:
			continue
		var clear_pipe_entrance = result as ClearPipeEntrance
		if player_movement.is_in_pipe:
			if player_movement.pipe_in_cooldown > 0:
				return

			if clear_pipe_entrance.has_meta("overlapping_with_block"):
				clear_pipe_blocked_counter += 1
				if clear_pipe_blocked_counter >= 2:
					emit_signal("player_pipe_blocked")
					return
				match player_movement.pipe_moving_dir:
					PlayerMovement.PipeMoveDirection.LEFT:
						player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.RIGHT
					PlayerMovement.PipeMoveDirection.RIGHT:
						player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.LEFT
					PlayerMovement.PipeMoveDirection.UP:
						player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.DOWN
					PlayerMovement.PipeMoveDirection.DOWN:
						player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.UP
				clear_turning_processed_for_reversal()
				return

			player_movement.exit_pipe()
			player.position = clear_pipe_entrance.global_position
			player.force_update_transform()
			return
		match clear_pipe_entrance.entrance_direction:
			ClearPipeEntrance.Direction.LEFT:
				if not player.is_on_wall() or not player.is_on_floor() or not Input.is_action_pressed("move_left") \
				or player.global_position.y > clear_pipe_entrance.global_position.y + 24.0:
					break
				player_movement.enter_pipe(PlayerMovement.PipeMoveDirection.LEFT)
			ClearPipeEntrance.Direction.RIGHT:
				if not player.is_on_wall() or not player.is_on_floor() or not Input.is_action_pressed("move_right") \
				or player.global_position.y > clear_pipe_entrance.global_position.y + 24.0:
					break
				player_movement.enter_pipe(PlayerMovement.PipeMoveDirection.RIGHT)
			ClearPipeEntrance.Direction.UP:
				if not player.is_on_ceiling() or not Input.is_action_pressed("move_up"):
					break
				player_movement.enter_pipe(PlayerMovement.PipeMoveDirection.UP)
			ClearPipeEntrance.Direction.DOWN:
				if not player.is_on_floor() or not Input.is_action_pressed("move_down"):
					break
				player_movement.enter_pipe(PlayerMovement.PipeMoveDirection.DOWN)
		player.position = clear_pipe_entrance.turning_area.global_position if is_instance_valid(clear_pipe_entrance.turning_area) else clear_pipe_entrance.global_position
		clear_pipe_entrance.overlapped_ids[player.get_instance_id()] = true
		break

func clear_pipe_turning_detect(results: Array[Node2D]) -> void:
	for result in results:
		if not is_instance_valid(result) or not result is ClearPipeTurningArea2D:
			continue
		var area = result as ClearPipeTurningArea2D

		# 已经处理过的区域不再重复转向
		if area.is_processed(player):
			continue

		var target = area.global_position + Vector2(0, 8)
		var diff = target - player.global_position

		# 如果需要位置对齐
		if abs(diff.x) > 0.5 or abs(diff.y) > 0.5:
			if not is_origin_pipe_dir_set:
				origin_player_pipe_dir = player_movement.pipe_moving_dir
				is_origin_pipe_dir_set = true
			player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.ALIGN
			player.global_position = player.global_position.move_toward(target, 4.0)
			continue

		# --- 对齐完成，执行转向 ---
		if is_origin_pipe_dir_set:
			player_movement.pipe_moving_dir = origin_player_pipe_dir
			is_origin_pipe_dir_set = false

		match area.direction:
			ClearPipeSet.Direction.LEFT:
				if player_movement.pipe_moving_dir != PlayerMovement.PipeMoveDirection.LEFT:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.RIGHT
			ClearPipeSet.Direction.RIGHT:
				if player_movement.pipe_moving_dir != PlayerMovement.PipeMoveDirection.RIGHT:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.LEFT
			ClearPipeSet.Direction.UP:
				if player_movement.pipe_moving_dir != PlayerMovement.PipeMoveDirection.UP:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.DOWN
			ClearPipeSet.Direction.DOWN:
				if player_movement.pipe_moving_dir != PlayerMovement.PipeMoveDirection.DOWN:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.UP
			ClearPipeSet.Direction.LEFT_UP:
				if player_movement.pipe_moving_dir == PlayerMovement.PipeMoveDirection.RIGHT:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.UP
				elif player_movement.pipe_moving_dir == PlayerMovement.PipeMoveDirection.DOWN:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.LEFT
			ClearPipeSet.Direction.LEFT_DOWN:
				if player_movement.pipe_moving_dir == PlayerMovement.PipeMoveDirection.RIGHT:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.DOWN
				elif player_movement.pipe_moving_dir == PlayerMovement.PipeMoveDirection.UP:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.LEFT
			ClearPipeSet.Direction.RIGHT_UP:
				if player_movement.pipe_moving_dir == PlayerMovement.PipeMoveDirection.LEFT:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.UP
				elif player_movement.pipe_moving_dir == PlayerMovement.PipeMoveDirection.DOWN:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.RIGHT
			ClearPipeSet.Direction.RIGHT_DOWN:
				if player_movement.pipe_moving_dir == PlayerMovement.PipeMoveDirection.LEFT:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.DOWN
				elif player_movement.pipe_moving_dir == PlayerMovement.PipeMoveDirection.UP:
					player_movement.pipe_moving_dir = PlayerMovement.PipeMoveDirection.RIGHT

		# 标记为已处理，防止再次触发
		area.mark_processed(player)

func _on_pipe_exited() -> void:
	pipe_get_close_timer = 0
	is_origin_pipe_dir_set = false
	origin_player_pipe_dir = PlayerMovement.PipeMoveDirection.ALIGN
	clear_pipe_blocked_counter = 0

func clear_turning_processed_for_reversal() -> void:
	var turnings = get_tree().get_nodes_in_group("clear_pipe_turning_area")
	for turning in turnings:
		if is_instance_valid(turning) and turning is ClearPipeTurningArea2D:
			turning.clear_processed(player)

func door_detect(results: Array[Node2D]) -> void:
	if not player_movement:
		return
	if not player:
		return
	if not player.is_on_floor():
		return
	if not Input.is_action_pressed("move_up"):
		return
	if int(round(player_movement.rotate_with_up)) % 360 != 0:
		return
	if player_movement.is_in_door:
		return
	for result in results:
		if not result.has_meta("door_component"):
			continue
		var door = result.get_meta("door_component")
		if door is not DoorComponent:
			continue
		if player.global_position.y > door.global_position.y + 8.0 \
		or player.global_position.y < door.global_position.y - 8.0:
			continue
		if not door.try_enter():
			continue
		player_movement.enter_door(door.id, door)

func triangle_block_detect(results: Array[Node2D]) -> void:
	player_movement.is_on_triangle = false
	for result in results:
		var triangle_block_settings = result.get_node_or_null("%TriangleBlockSettings")
		if not triangle_block_settings:
			continue
		
		player_movement.is_on_triangle = true

		'''
		# 根据角度来判断方向
		match triangle_block_settings.triangle_dir:
			TriangleBlockSettings.TriangleDir.BOTTOM_RIGHT:
				pass
		'''