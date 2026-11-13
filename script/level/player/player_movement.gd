extends Node

class_name PlayerMovement

signal pipe_entered
signal pipe_exited
signal door_entered
signal door_exited
signal play_sound_jump
signal play_sound_break_tile
signal play_sound_bee
signal screen_shake

@export var player: CharacterBody2D
@export var player_suit: PlayerSuit

@export var collision_shape: CollisionShape2D
@export var cast: ShapeCast2D

@export var shape_small: Shape2D
@export var shape_super: Shape2D
@export var shape_big: Shape2D
@export var shape_big_crouch: Shape2D

@export var crouch_head_area: Area2D

# 碰撞箱补丁（移植自 Mario Forever Green Tea Engine）：
# 矩形碰撞盒没有原八边形的倒角，需要用两项修正补回官作的擦角手感。
@export var enable_collision_patch: bool = true
## 自动迈台阶：地面上水平移动被纯竖直矮墙挡住时，最多抬身该像素数越过（GTE 玩家值 12），0 = 关闭。
@export var step_up_amount: int = 12
## 顶天花板擦角：上升时若头顶只擦到方块边缘，最多左右让出该像素数（GTE 默认值 5），0 = 关闭。
@export var ceiling_corner_amount: int = 5

@export var max_speed_x: float = 400.0
@export var acceleration: float = 10.0
@export var deceleration_ground: float = 13.3
@export var deceleration_air: float = 1.7

@export var jump_speed: float = 600
@export var jump_speed_factor: float = 1.1
@export var max_speed_y: float = 650

@export var gravity_normal: float = 40
@export var gravity_hold_jump: float = 20.8

@export var gravity_normal_lui: float = 38.3
@export var gravity_hold_jump_lui: float = 16.7

@export var horizontal_spring_bounce_speed_x: float = 500.0

@export_range(-360.0, 360.0, 5.0) var rotate_with_up: float = 0.0:
	set(value):
		rotate_with_up = value
		player.rotation_degrees = rotate_with_up
		player.up_direction = Vector2(sin(deg_to_rad(rotate_with_up)), -cos(deg_to_rad(rotate_with_up)))

@export var triangle_speed_x_limit: float = 300.0

var move_up: bool
var move_down: bool
var move_left: bool
var move_right: bool
var move_fire: bool
var move_jump: bool

var fire: String = "move_fire"
var jump: String = "move_jump"

var jumpable: bool
var jumpable_time: int = 20
var jumpable_timer: int

var crouch: bool

# 传送中通用 flag
var is_in_transport: bool = false

# 透明水管
var is_in_pipe: bool = false
var out_pipe_cooldown: int = 0
var pipe_in_cooldown: int = 0

enum PipeMoveDirection {
	LEFT,
	RIGHT,
	UP,
	DOWN,
	ALIGN,
}
var pipe_moving_dir: PipeMoveDirection = PipeMoveDirection.ALIGN

# 门
var is_in_door: bool = false
var in_door_timer: int = 0
var target_doors: Array
var target_door: DoorComponent

# 狼跳
var langtiao: bool
var langtiao_time: int = 10
var langtiao_timer: int

var speed_x: float
var target_speed: float
var speed_y: float

# 多重力
var is_on_triangle: bool = false
var target_gravity: float = 0.0
var is_switching_gravity: bool = false

# 重力切换时保持输入锁（-1=未锁定, 0-3=锁定的局部方向ID）
var input_lock: Array[int] = [-1, -1, -1, -1]

# 大马里奥，体积大
@export var break_tile_speed_y: float = 300.0
var break_tile_cd_floor: bool = false
var break_tile_cd_ceil: bool = false
var player_big_disable_jump: bool = false

# 蜜蜂马里奥飞行
var is_bee_flying: bool = false
@export var bee_fly_time_max: float = 65.0
@export var bee_max_rise_speed: float = 216.0
var bee_fly_timer: float = 0.0

@export var _block_fragment_scene: PackedScene = preload("uid://ct006nlnmf8dg")
const FRAMERATE_ORIGIN: float = 60.0
var _fragment_create_position: Array[Vector2] = [
	Vector2(-8.0, -8.0),
	Vector2(8.0, 8.0),
	Vector2(-8.0, 8.0),
	Vector2(8.0, -8.0),
]
var _fragment_velocity_data: Array[Vector2] = [
	Vector2(-3.0, -6.0) * FRAMERATE_ORIGIN,
	Vector2(-2.0, -4.0) * FRAMERATE_ORIGIN,
	Vector2(2.0, -4.0) * FRAMERATE_ORIGIN,
	Vector2(3.0, -6.0) * FRAMERATE_ORIGIN,
]



func _physics_process(delta: float) -> void:
	# 冷却递减必须放在 transport_check 之前，确保管道内也能正确递减
	if out_pipe_cooldown > 0:
		out_pipe_cooldown -= 1
		jumpable = false
	if pipe_in_cooldown > 0:
		pipe_in_cooldown -= 1

	# 处理输入
	_update_directional_input()
	move_fire = Input.is_action_pressed("move_fire")
	move_jump = Input.is_action_pressed("move_jump")
	
	if transport_check():
		return

	# 水平运动
	target_speed = 0.0
	
	if player.is_on_wall():
		if player.is_on_floor():
			_player_big_break_tile_wall()
			speed_y = 0.0
		speed_x = 0.0

	# 下蹲
	if player.is_on_floor():
		if move_down:
			crouch = true

	if !move_down and player.is_on_floor() \
	and (crouch_head_area.get_overlapping_bodies().size() == 0 or player_suit.suit == PlayerSuit.SuitType.SMALL):
		crouch = false

	# 确定目标速度方向
	if !crouch or !player.is_on_floor():
		if move_left:
			target_speed = -max_speed_x
		elif move_right:
			target_speed = max_speed_x
	else:
		target_speed = 0.0
	
	# 应用加速度和减速度
	if target_speed != 0.0:
		# 加速阶段
		if speed_x != target_speed:
			var current_acceleration: float = acceleration
			if sign(target_speed) != sign(speed_x):
				current_acceleration *= 2
			speed_x = move_toward(speed_x, target_speed, current_acceleration)
	else:
		# 减速阶段
		var current_deceleration: float = deceleration_ground if player.is_on_floor() else deceleration_air
		speed_x = move_toward(speed_x, 0.0, current_deceleration)


	# 垂直运动
	if player_big_disable_jump:
		player_big_disable_jump = false

	if player.is_on_floor():
		# 大马里奥，体积大
		if speed_y > 100.0:
			speed_y = 0.0
			_player_big_break_tile_pound()
		else:
			speed_y = 0.0
		langtiao_timer = 0

	# 蜜蜂马里奥
	var is_bee: bool = player_suit.suit == PlayerSuit.SuitType.POWERED and player_suit.power == PlayerSuit.PowerupType.BEE
	if not is_bee:
		is_bee_flying = false
	if is_bee:
		if player.is_on_floor():
			is_bee_flying = false
			bee_fly_timer = 0.0
		if bee_fly_timer >= bee_fly_time_max:
			is_bee_flying = false
		if not is_bee_flying and not player.is_on_floor() and bee_fly_timer < bee_fly_time_max:
			if is_action_pressed("move_jump") or (move_jump and speed_y > 0.0):
				is_bee_flying = true

	if not player_big_disable_jump:
		if speed_y >= 0.0 and is_action_pressed(jump) and not is_bee_flying:
			jumpable = true
		if !player.is_on_floor():
			langtiao_timer += 1
			langtiao = langtiao_timer < langtiao_time
		if jumpable:
			jumpable_timer += 1
			if jumpable_timer > jumpable_time:
				jumpable = false
				jumpable_timer = 0
		if move_jump and jumpable and (player.is_on_floor() or (langtiao and speed_y > 0.0)):
			speed_y = -jump_speed
			break_tile_cd_floor = false
			break_tile_cd_ceil = false
			if abs(speed_x) > max_speed_x * 0.3:
				speed_y *= jump_speed_factor
			jumpable = false
			emit_signal("play_sound_jump")

	if player.is_on_ceiling():
		_player_big_break_tile_bump()
		speed_y = 0.0

	# 蜜蜂飞行
	if is_bee and is_bee_flying and move_jump and bee_fly_timer < bee_fly_time_max:
		bee_fly_timer += 1.0
		speed_y = maxf(-bee_max_rise_speed, speed_y - bee_max_rise_speed * 0.3)
		emit_signal("play_sound_bee")

	if not (is_bee and is_bee_flying and move_jump):
		var current_gravity: float = gravity_hold_jump if move_jump else gravity_normal
		if player_suit.power == PlayerSuit.PowerupType.LUI and player_suit.suit == PlayerSuit.SuitType.POWERED:
			current_gravity = gravity_hold_jump_lui if move_jump else gravity_normal_lui
		speed_y += current_gravity

	# 限制垂直速度
	speed_y = minf(speed_y, max_speed_y)


	# 多重力
	on_triangle_block()

	# 应用速度
	player.velocity = Vector2(-player.up_direction.y, player.up_direction.x) * speed_x - player.up_direction * speed_y
	_apply_collision_patches(delta)
	player.move_and_slide()

	# 掉落桥检测
	platform_fall_detect()

	# 更新碰撞箱
	update_hit_box()


func is_action_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)

# -----------------------------------------------------------------------------
# 矩形碰撞盒补丁（移植自 Mario Forever Green Tea Engine）
# 1) AutoStepUpComponent.TryStepUp()：地面上水平位移即将被纯竖直矮墙吃掉时，
#    逐像素抬身越过侧壁、水平走完本帧位移、再贴回台阶面；一帧内完成，不掉速、不浮空。
# 2) CorrectedCharacterBody2D.HorizontalCorrection()：上升顶到方块侧边角时，
#    左右各试 1~N 像素，找到头顶空位就把身体水平挤出边缘。
# 两项都在 move_and_slide 之前执行：此时 velocity 尚未被碰撞改写。
# 仅支持标准向下重力（GTE 的 Correction 组件同样未移植旋转重力）。
# -----------------------------------------------------------------------------
func _apply_collision_patches(delta: float) -> void:
	if not enable_collision_patch:
		return
	if absf(rotate_with_up) > 0.01 or is_switching_gravity:
		return
	_try_step_up(delta)
	_ceiling_corner_correction(delta)


func _try_step_up(delta: float) -> void:
	if step_up_amount <= 0:
		return
	# 只在非上升状态迈步：站着、贴地或正在下落都允许。
	# 跑过「砖-空-砖」一格坑时脚底已低于对侧砖顶几像素，此时 is_on_floor 为 false，
	# 若死守 on_floor 就永远迈不上去（矩形盒没有原八边形的底部倒角可蹭）。
	if player.velocity.y < 0.0:
		return
	if absf(player.velocity.x) <= 1.0:
		return
	# 只用水平分量预判：重力带来的竖直分量会先撞地面，使第一碰撞恒为地面而误判
	var motion: Vector2 = Vector2(player.velocity.x * delta, 0.0)
	var collision: KinematicCollision2D = player.move_and_collide(motion, true, 0.08, false)
	if collision == null:
		return
	var normal: Vector2 = collision.get_normal()
	# 只认纯竖直墙（矮台阶侧壁）；斜面 / 天花板不迈步
	if absf(normal.x) < 0.999 or absf(normal.y) >= 0.1:
		return
	for i: int in range(1, step_up_amount + 2):
		var from: Transform2D = player.global_transform.translated(Vector2(0.0, -float(i)))
		if player.test_move(from, motion):
			continue
		player.translate(Vector2(0.0, -float(i)))
		player.move_and_collide(Vector2(motion.x, 0.0))
		player.move_and_collide(Vector2(0.0, float(i)))
		# 本帧水平位移已消费，清掉 body 的水平速度，避免随后 move_and_slide 再走一次；
		# 脚本里的 speed_x 保留（下一帧照常用它计算速度）
		var velocity: Vector2 = player.velocity
		velocity.x = 0.0
		player.velocity = velocity
		return


func _ceiling_corner_correction(delta: float) -> void:
	if ceiling_corner_amount <= 0 or player.velocity.y >= 0.0:
		return
	var motion: Vector2 = Vector2(0.0, player.velocity.y * delta)
	var collision: KinematicCollision2D = player.move_and_collide(motion, true, 0.001, false)
	if collision == null:
		return
	var normal: Vector2 = collision.get_normal()
	# 法线偏水平说明撞的是侧壁而非天花板，不处理
	if absf(normal.x) >= 0.4:
		return
	var directions: Array[int] = [-1, 1]
	for i: int in range(1, ceiling_corner_amount + 1):
		for j: int in directions:
			var offset: float = float(i * j)
			var from: Transform2D = player.global_transform.translated(Vector2(offset, 0.0))
			if player.test_move(from, motion):
				continue
			player.translate(Vector2(offset, 0.0))
			var velocity: Vector2 = player.velocity
			# 挤出方向与水平速度相反时清掉水平速度（与 GTE 一致）
			if velocity.x * float(j) < 0.0:
				velocity.x = 0.0
			player.velocity = velocity
			return


func platform_fall_detect() -> void:
	if !player.is_on_floor():
		return
	var result: KinematicCollision2D = player.move_and_collide(Vector2.DOWN, true)
	#print(result)
	if not result:
		return
	if result.get_collider().has_meta("platform_fall_movement"):
		var platform_fall_movement: PlatformFallMovement = result.get_collider().get_meta("platform_fall_movement")
		#print(platform_fall_movement)
		platform_fall_movement.fall()

class SizeStatus:
	enum SizeType {
		SMALL,
		SUPER,
		BIG,
		BIG_CROUCH,
	}

func update_hit_box() -> void:
	var target_shape: Shape2D
	# 与 Green Tea Engine 一致：小个子 19x26 居中于身体原点，大个子 19x52 上移 13px，
	# 两档脚线都固定在 +13（BIG 系列沿用本工程宽度，高度同为 52/26）。
	var target_position: Vector2
	if crouch or player_suit.suit == PlayerSuit.SuitType.SMALL:
		target_shape = shape_small
		target_position = Vector2(0, 0)
	else:
		target_shape = shape_super
		target_position = Vector2(0, -13)
	if player_suit.suit == PlayerSuit.SuitType.POWERED and player_suit.power == PlayerSuit.PowerupType.BIG:
		target_shape = shape_big
		target_position = Vector2(0, -13)
		if crouch:
			target_shape = shape_big_crouch
			target_position = Vector2(0, 0)

	collision_shape.shape = target_shape
	cast.shape = target_shape
	collision_shape.position = target_position
	cast.position = target_position

func transport_check() -> bool:
	is_in_transport = pipe_check() or door_check()
	return is_in_transport

func pipe_check() -> bool:
	if is_in_pipe:
		pipe_movement()
	return is_in_pipe

func enter_pipe(enter_direction: PipeMoveDirection) -> void:
	crouch = true
	pipe_moving_dir = enter_direction
	is_in_pipe = true
	pipe_in_cooldown = 5
	player.set_meta("is_in_pipe", true)
	speed_x = 0.0
	speed_y = 0.0
	is_switching_gravity = false
	var pipe_move_vec: Vector2
	match enter_direction:
		PipeMoveDirection.LEFT:
			pipe_move_vec = Vector2(-1, 0)
		PipeMoveDirection.RIGHT:
			pipe_move_vec = Vector2(1, 0)
		PipeMoveDirection.UP:
			pipe_move_vec = Vector2(0, -1)
		PipeMoveDirection.DOWN:
			pipe_move_vec = Vector2(0, 1)
	player.position = player.position + pipe_move_vec * 16
	emit_signal("pipe_entered")

func exit_pipe() -> void:
	is_in_pipe = false
	player.remove_meta("is_in_pipe")
	out_pipe_cooldown = 10
	pipe_in_cooldown = 0
	var turnings: Array[Node] = get_tree().get_nodes_in_group("clear_pipe_turning_area")
	for turning: Node in turnings:
		if is_instance_valid(turning) and turning is ClearPipeTurningArea2D:
			var turning_area: ClearPipeTurningArea2D = turning
			turning_area.clear_processed(player)
	var entrances: Array[Node] = get_tree().get_nodes_in_group("clear_pipe_entrance")
	for entrance: Node in entrances:
		if is_instance_valid(entrance) and entrance is ClearPipeEntrance:
			var entrance_node: ClearPipeEntrance = entrance
			entrance_node.clear_overlapped(player)
	
	pipe_moving_dir = PipeMoveDirection.ALIGN
	emit_signal("pipe_exited")

func pipe_movement() -> void:
	var moving_speed: float = 4.0
	match pipe_moving_dir:
		PipeMoveDirection.LEFT:
			player.position = player.position + Vector2(-moving_speed, 0)
		PipeMoveDirection.RIGHT:
			player.position = player.position + Vector2(moving_speed, 0)
		PipeMoveDirection.UP:
			player.position = player.position + Vector2(0, -moving_speed)
		PipeMoveDirection.DOWN:
			player.position = player.position + Vector2(0, moving_speed)
	player.force_update_transform()

func on_horizontal_spring_bounce(spring: Node2D) -> void:
	var dir: float = (1.0 if player.global_position.x > spring.global_position.x else -1.0) \
			* (1.0 if roundi(target_gravity) % 360 == 0 else -1.0)
	speed_x = abs(horizontal_spring_bounce_speed_x) * dir

func door_check() -> bool:
	if is_in_door:
		door_movement()
	return is_in_door

func enter_door(door_id: int, door: DoorComponent) -> void:
	if is_in_door:
		return
	is_in_door = true
	target_doors.clear()
	var all_doors: Array[Node] = get_tree().get_nodes_in_group("door")
	for d: Node in all_doors:
		var door_node: DoorComponent = d
		if door_node.id == door_id and target_doors.size() < 2:
			target_doors.append(door_node)
	for d: Variant in target_doors:
		var target_enter_door: DoorComponent = d
		target_enter_door.play_animation_enter()
		if target_enter_door == door:
			continue
		target_door = target_enter_door
	speed_x = 0.0
	in_door_timer = 0
	emit_signal("door_entered")

func exit_door() -> void:
	is_in_door = false
	emit_signal("door_exited")

func door_movement() -> void:
	in_door_timer += 1
	match in_door_timer:
		50:
			player.global_position = target_door.global_position + Vector2(0, 3.5)
			player.reset_physics_interpolation()
			for d: Variant in target_doors:
				var target_exit_door: DoorComponent = d
				target_exit_door.play_animation_exit()
		100:
			exit_door()

func _snap_to_ground() -> void:
	var snap: KinematicCollision2D = player.move_and_collide(-player.up_direction * 32.0)
	if snap:
		speed_y = 0.0

func on_triangle_block() -> void:
	if is_switching_gravity:
		rotate_with_up = move_toward(rotate_with_up, target_gravity, 10.0)
		_snap_to_ground()
		if abs(rotate_with_up - target_gravity) < 10.0:
			rotate_with_up = target_gravity
			if not is_on_triangle:
				is_switching_gravity = false
		return

	if not player.is_on_floor():
		return

	if is_on_triangle and not is_switching_gravity:
		if speed_x > triangle_speed_x_limit:
			target_gravity -= 90.0
			is_switching_gravity = true
			_lock_current_input()
		elif speed_x < -triangle_speed_x_limit:
			target_gravity += 90.0
			is_switching_gravity = true
			_lock_current_input()

func _lock_current_input() -> void:
	var raw: Array[bool] = [
		Input.is_action_pressed("move_right"),
		Input.is_action_pressed("move_up"),
		Input.is_action_pressed("move_left"),
		Input.is_action_pressed("move_down"),
	]
	var step: int = wrapi(roundi(-rotate_with_up / 90.0), 0, 4)
	var grav: Array = _INPUT_ID_MAP[step]
	for key_idx: int in range(4):
		if raw[key_idx]:
			if input_lock[key_idx] == -1:
				input_lock[key_idx] = grav[key_idx]
		else:
			input_lock[key_idx] = -1

const _INPUT_ID_MAP: Array[Array] = [
	[0, 1, 2, 3],  #  0°:   →=→  ↑=↑  ←=←  ↓=↓
	[3, 0, 1, 2],  # -90°:  →=↓  ↑=→  ←=↑  ↓=←
	[2, 3, 0, 1],  #-180°:  →=←  ↑=↓  ←=→  ↓=↑
	[1, 2, 3, 0],  #-270°:  →=↑  ↑=←  ←=↓  ↓=→
]

func _set_move_dir(idx: int, val: bool) -> void:
	match idx:
		0: move_right = val
		1: move_up = val
		2: move_left = val
		3: move_down = val

func _update_directional_input() -> void:
	var raw: Array[bool] = [
		Input.is_action_pressed("move_right"),  # 0
		Input.is_action_pressed("move_up"),     # 1
		Input.is_action_pressed("move_left"),   # 2
		Input.is_action_pressed("move_down"),   # 3
	]

	var step: int = wrapi(roundi(-rotate_with_up / 90.0), 0, 4)
	var grav: Array = _INPUT_ID_MAP[step]

	move_right = false
	move_up = false
	move_left = false
	move_down = false

	for key_idx: int in range(4):
		if not raw[key_idx]:
			input_lock[key_idx] = -1
		elif input_lock[key_idx] != -1:
			_set_move_dir(input_lock[key_idx], true)
		else:
			var grav_id: int = grav[key_idx]
			_set_move_dir(grav_id, true)

# 大马里奥踩硬砖
func _player_big_break_tile_pound() -> void:
	if break_tile_cd_floor:
		return
	break_tile_cd_floor = true

	var motion: Vector2 = Vector2(-player.up_direction * 8.0)
	var collision: KinematicCollision2D = player.move_and_collide(motion, true)
	_hard_breakable_block_collide(collision, motion)

func _player_big_break_tile_bump() -> void:
	if break_tile_cd_ceil:
		return
	break_tile_cd_ceil = true
	var motion: Vector2 = Vector2(player.up_direction * 8.0)
	var collision: KinematicCollision2D = player.move_and_collide(motion, true)
	_hard_breakable_block_collide(collision, motion)

func _player_big_break_tile_wall() -> void:
	var motion: Vector2 = Vector2(player.velocity.normalized() * 2.0)
	var collision: KinematicCollision2D = player.move_and_collide(motion, true)
	_hard_breakable_block_collide(collision, motion)

func _hard_breakable_block_collide(collision: KinematicCollision2D, motion: Vector2) -> void:
	if not (player_suit.suit == PlayerSuit.SuitType.POWERED and \
		player_suit.power == PlayerSuit.PowerupType.BIG):
			return
	if not collision:
		return
	var collider: Node2D = collision.get_collider()
	if collider is TileMapLayer:
		var tilemap: TileMapLayer = collider
		
		var offsets: Array[Vector2] = [Vector2(0.5, 0), Vector2(-0.5, 0), Vector2(0, 0.5), Vector2(0, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(0.5, -0.5), Vector2(-0.5, -0.5)]
		var hit_cell: Variant = null
		for off: Vector2 in offsets:
			var pt: Vector2 = collision.get_position() + off
			var local_pt: Vector2 = tilemap.to_local(pt)
			var cell: Vector2i = tilemap.local_to_map(local_pt)
			var td: TileData = tilemap.get_cell_tile_data(cell)
			if td and td.get_custom_data("big_breakable"):
				hit_cell = cell
				break

		if hit_cell != null:
			var hit_cell_v: Vector2i = hit_cell
			var cp: Vector2i = Vector2i(hit_cell_v.x, hit_cell_v.y)
			var tile_tex: Texture2D = null
			var source_id: int = tilemap.get_cell_source_id(cp)
			var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(cp)
			if source_id >= 0 and atlas_coords != Vector2i(-1, -1):
				var source: TileSetAtlasSource = tilemap.tile_set.get_source(source_id)
				if source:
					var atlas_tex: AtlasTexture = AtlasTexture.new()
					atlas_tex.atlas = source.texture
					atlas_tex.region = source.get_tile_texture_region(atlas_coords)
					tile_tex = atlas_tex
			tilemap.erase_cell(cp)
			_spawn_fragments(tilemap.map_to_local(cp), tile_tex)
			tilemap.update_internals()
			speed_y = -break_tile_speed_y
			player_big_disable_jump = true
			emit_signal("play_sound_break_tile")
			
			# 递归检测连续碰撞
			var collision2: KinematicCollision2D = player.move_and_collide(motion, true)
			_hard_breakable_block_collide(collision2, motion)


	if collider.has_meta("hard_breakable_block"):
		var block_tex: Texture2D = null
		for child: Node in collider.get_children():
			if child is Sprite2D:
				var sprite_child: Sprite2D = child
				block_tex = sprite_child.texture
				break
			elif child is AnimatedSprite2D:
				var anim_child: AnimatedSprite2D = child
				var anim: StringName = anim_child.animation
				if anim and anim_child.sprite_frames.has_animation(anim):
					block_tex = anim_child.sprite_frames.get_frame_texture(anim, anim_child.frame)
				break
		_spawn_fragments(collider.global_position, block_tex)
		collider.free()
		speed_y = -break_tile_speed_y
		player_big_disable_jump = true
		emit_signal("play_sound_break_tile")

		# 神秘递归
		var collision2: KinematicCollision2D = player.move_and_collide(motion, true)
		_hard_breakable_block_collide(collision2, motion)


func _spawn_fragments(world_pos: Vector2, tex: Texture2D = null) -> void:
	emit_signal("screen_shake")
	for i: int in _fragment_velocity_data.size():
		var f: BlockFragment = _block_fragment_scene.instantiate()
		if tex:
			f.sprite.texture = tex
		f.global_position = world_pos + _fragment_create_position[i]
		f.reset_physics_interpolation()
		f.speed_x = _fragment_velocity_data[i].x
		f.speed_y = _fragment_velocity_data[i].y
		player.get_parent().add_child(f)
