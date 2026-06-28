extends Node

class_name PlayerMovement

signal pipe_entered
signal pipe_exited
signal door_entered
signal door_exited
signal play_sound_jump
signal play_sound_break_tile

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

@export var player : CharacterBody2D
@export var player_suit : PlayerSuit

@export var collision_shape : CollisionShape2D
@export var cast : ShapeCast2D

@export var shape_small : Shape2D
@export var shape_super : Shape2D
@export var shape_big : Shape2D
@export var shape_big_crouch: Shape2D

@export var crouch_head_area : Area2D

@export var max_speed_x : float = 400.0
@export var acceleration : float = 600.0
@export var deceleration_ground : float = 800.0
@export var deceleration_air : float = 100.0

@export var jump_speed : float = 600
@export var jump_speed_factor : float = 1.1
@export var max_speed_y : float = 650

@export var gravity_normal = 2400
@export var gravity_hold_jump = 1250

@export var gravity_normal_lui = 2300
@export var gravity_hold_jump_lui = 1000

@export var horizontal_spring_bounce_speed_x: float = 500.0

@export_range(-360.0, 360.0, 5.0) var rotate_with_up: float = 0.0:
	set(value):
		rotate_with_up = value
		player.rotation_degrees = rotate_with_up
		player.up_direction = Vector2(sin(deg_to_rad(rotate_with_up)), -cos(deg_to_rad(rotate_with_up)))

@export var triangle_speed_x_limit: float = 300.0

var move_up : bool
var move_down : bool
var move_left : bool
var move_right : bool
var move_fire : bool
var move_jump : bool

var fire : String = "move_fire"
var jump : String = "move_jump"

var jumpable : bool
var jumpable_time : int = 20
var jumpable_timer : int

var crouch : bool

# 传送中通用 flag
var is_in_transport : bool = false

# 透明水管
var is_in_pipe : bool = false
var out_pipe_cooldown : int = 0
var pipe_in_cooldown : int = 0

enum PipeMoveDirection {
	LEFT,
	RIGHT,
	UP,
	DOWN,
	ALIGN,
}
var pipe_moving_dir : PipeMoveDirection = PipeMoveDirection.ALIGN

# 门
var is_in_door : bool = false
var in_door_timer : int = 0
var target_doors : Array
var target_door : DoorComponent

# 狼跳
var langtiao : bool
var langtiao_time : int = 10
var langtiao_timer : int

var speed_x : float
var target_speed : float
var speed_y : float

# 多重力
var is_on_triangle: bool = false
var target_gravity : float = 0.0
var is_switching_gravity: bool = false

# 重力切换时保持输入锁（-1=未锁定, 0-3=锁定的局部方向ID）
var input_lock: Array[int] = [-1, -1, -1, -1]

# 大马里奥，体积大
@export var break_tile_speed_y: float = 300.0
var break_tile_cd_floor: bool = false
var break_tile_cd_ceil: bool = false
var player_big_disable_jump: bool = false


func _physics_process(delta):
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
			var current_acceleration = acceleration
			if sign(target_speed) != sign(speed_x):
				current_acceleration *= 2
			speed_x = move_toward(speed_x, target_speed, current_acceleration * delta)
	else:
		# 减速阶段
		var current_deceleration = deceleration_ground if player.is_on_floor() else deceleration_air
		speed_x = move_toward(speed_x, 0.0, current_deceleration * delta)


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

	if not player_big_disable_jump:
		if speed_y >= 0.0 and is_action_pressed(jump):
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
			if abs(speed_x) > max_speed_x * 0.3:
				speed_y *= jump_speed_factor
			jumpable = false
			emit_signal("play_sound_jump")

	if player.is_on_ceiling():
		_player_big_break_tile_bump()
		speed_y = 0.0
	
	var current_gravity = gravity_hold_jump if move_jump else gravity_normal
	if player_suit.power == PlayerSuit.PowerupType.LUI and player_suit.suit == PlayerSuit.SuitType.POWERED:
		current_gravity = gravity_hold_jump_lui if move_jump else gravity_normal_lui
	speed_y += current_gravity * delta

	# 限制垂直速度
	speed_y = minf(speed_y, max_speed_y)


	# 多重力
	on_triangle_block()

	# 应用速度
	player.velocity = Vector2(-player.up_direction.y, player.up_direction.x) * speed_x - player.up_direction * speed_y
	player.move_and_slide()

	# 掉落桥检测
	platform_fall_detect()

	# 更新碰撞箱
	update_hit_box()


func is_action_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)

func platform_fall_detect() -> void:
	if !player.is_on_floor():
		return
	var result = player.move_and_collide(Vector2.DOWN, true)
	#print(result)
	if not result:
		return
	if result.get_collider().has_meta("platform_fall_movement"):
		var platform_fall_movement = result.get_collider().get_meta("platform_fall_movement") as PlatformFallMovement
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
	var target_position: Vector2
	if crouch or player_suit.suit == PlayerSuit.SuitType.SMALL:
		target_shape = shape_small
		target_position = Vector2(0, -1.5)
	else:
		target_shape = shape_super
		target_position = Vector2(0, -16.5)
	if player_suit.suit == PlayerSuit.SuitType.POWERED and player_suit.power == PlayerSuit.PowerupType.BIG:
		target_shape = shape_big
		target_position = Vector2(0, -16.5)
		if crouch:
			target_shape = shape_big_crouch
			target_position = Vector2(0, -1.5)

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

func enter_pipe(enter_direction : PipeMoveDirection) -> void:
	crouch = true
	pipe_moving_dir = enter_direction
	is_in_pipe = true
	pipe_in_cooldown = 5
	player.set_meta("is_in_pipe", true)
	speed_x = 0.0
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
	player.position = player.position + pipe_move_vec * 16
	emit_signal("pipe_entered")

func exit_pipe() -> void:
	is_in_pipe = false
	player.remove_meta("is_in_pipe")
	out_pipe_cooldown = 10
	pipe_in_cooldown = 0
	var turnings = get_tree().get_nodes_in_group("clear_pipe_turning_area")
	for turning in turnings:
		if is_instance_valid(turning) and turning is ClearPipeTurningArea2D:
			turning.clear_processed(player)
	var entrances = get_tree().get_nodes_in_group("clear_pipe_entrance")
	for entrance in entrances:
		if is_instance_valid(entrance) and entrance is ClearPipeEntrance:
			entrance.clear_overlapped(player)
	
	pipe_moving_dir = PipeMoveDirection.ALIGN
	emit_signal("pipe_exited")

func pipe_movement() -> void:
	var moving_speed : float = 4.0
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
	var dir = 1.0 if player.global_position.x > spring.global_position.x else -1.0
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
	var all_doors = get_tree().get_nodes_in_group("door")
	for d in all_doors:
		if d.id == door_id and target_doors.size() < 2:
			target_doors.append(d)
	for d in target_doors:
		d.play_animation_enter()
		if d == door:
			continue
		target_door = d
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
			for d in target_doors:
				d.play_animation_exit()
		100:
			exit_door()

func _snap_to_ground() -> void:
	var snap = player.move_and_collide(-player.up_direction * 32.0)
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
	var raw = [
		Input.is_action_pressed("move_right"),
		Input.is_action_pressed("move_up"),
		Input.is_action_pressed("move_left"),
		Input.is_action_pressed("move_down"),
	]
	var step = wrapi(int(round(-rotate_with_up / 90.0)), 0, 4)
	var grav = _INPUT_ID_MAP[step]
	for key_idx in range(4):
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
	var raw = [
		Input.is_action_pressed("move_right"),  # 0
		Input.is_action_pressed("move_up"),     # 1
		Input.is_action_pressed("move_left"),   # 2
		Input.is_action_pressed("move_down"),   # 3
	]

	var step = wrapi(int(round(-rotate_with_up / 90.0)), 0, 4)
	var grav = _INPUT_ID_MAP[step]

	move_right = false
	move_up = false
	move_left = false
	move_down = false

	for key_idx in range(4):
		if not raw[key_idx]:
			input_lock[key_idx] = -1
		elif input_lock[key_idx] != -1:
			_set_move_dir(input_lock[key_idx], true)
		else:
			_set_move_dir(grav[key_idx], true)

# 大马里奥踩硬砖
func _player_big_break_tile_pound() -> void:
	if break_tile_cd_floor:
		return
	break_tile_cd_floor = true

	var motion = Vector2(-player.up_direction * 8.0)
	var collision = player.move_and_collide(motion, true)
	_hard_breakable_block_collide(collision, motion)

func _player_big_break_tile_bump() -> void:
	if break_tile_cd_ceil:
		return
	break_tile_cd_ceil = true
	var motion = Vector2(player.up_direction * 8.0)
	var collision = player.move_and_collide(motion, true)
	_hard_breakable_block_collide(collision, motion)

func _player_big_break_tile_wall() -> void:
	var motion = Vector2(player.velocity.normalized() * 2.0)
	var collision = player.move_and_collide(motion, true)
	_hard_breakable_block_collide(collision, motion)

func _hard_breakable_block_collide(collision: KinematicCollision2D, motion: Vector2) -> void:
	if not (player_suit.suit == PlayerSuit.SuitType.POWERED and \
		player_suit.power == PlayerSuit.PowerupType.BIG):
			return
	if not collision:
		return
	var collider = collision.get_collider()
	if collider is TileMapLayer:

		var tilemap = collision.get_collider() as TileMapLayer
		var hit_cell = tilemap.local_to_map(tilemap.to_local(collision.get_position()) - collision.get_normal())

		var tile_size = tilemap.tile_set.tile_size
		var shape = collision_shape.shape
		var half_in_tiles = 1
		if shape is RectangleShape2D:
			half_in_tiles = ceili(shape.size.x / tile_size.x / 2.0)
		elif shape is CapsuleShape2D:
			half_in_tiles = ceili(shape.radius * 2.0 / tile_size.x / 2.0)
		half_in_tiles = max(1, half_in_tiles)

		var erased := false
		for dx in range(-half_in_tiles, half_in_tiles + 1):
			var cp = Vector2i(hit_cell.x + dx, hit_cell.y)
			var td = tilemap.get_cell_tile_data(cp)
			if td and td.get_custom_data("big_breakable"):
				tilemap.set_cell(cp, -1)
				erased = true
				_spawn_fragments(tilemap.map_to_local(cp))
				emit_signal("play_sound_break_tile")
				speed_y = -break_tile_speed_y
				player_big_disable_jump = true
	
		if erased:
			tilemap.update_internals()


	if collider.has_meta("hard_breakable_block"):
		_spawn_fragments(collider.global_position)
		collider.free()
		speed_y = -break_tile_speed_y
		player_big_disable_jump = true
		emit_signal("play_sound_break_tile")

		# 神秘递归
		var collision2 = player.move_and_collide(motion, true)
		_hard_breakable_block_collide(collision2, motion)


func _spawn_fragments(world_pos: Vector2) -> void:
	for i in _fragment_velocity_data.size():
		var f = _block_fragment_scene.instantiate()
		f.global_position = world_pos + _fragment_create_position[i]
		f.reset_physics_interpolation()
		f.speed_x = _fragment_velocity_data[i].x
		f.speed_y = _fragment_velocity_data[i].y
		player.get_parent().add_child(f)
