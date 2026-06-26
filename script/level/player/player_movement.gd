extends Node

class_name PlayerMovement

signal pipe_entered
signal pipe_exited
signal door_entered
signal door_exited
signal play_sound_jump

@export var player : CharacterBody2D
@export var player_suit : PlayerSuit

@export var collision_shape : CollisionShape2D
@export var cast : ShapeCast2D

@export var shape_small : Shape2D
@export var shape_super : Shape2D

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


func _physics_process(delta):
	# 冷却递减必须放在 transport_check 之前，确保管道内也能正确递减
	if out_pipe_cooldown > 0:
		out_pipe_cooldown -= 1
		jumpable = false
	if pipe_in_cooldown > 0:
		pipe_in_cooldown -= 1

	# 处理输入
	move_up = Input.is_action_pressed("move_up")
	move_down = Input.is_action_pressed("move_down")
	move_left = Input.is_action_pressed("move_left")
	move_right = Input.is_action_pressed("move_right")
	move_fire = Input.is_action_pressed("move_fire")
	move_jump = Input.is_action_pressed("move_jump")
	
	if transport_check():
		return

	# 水平运动
	target_speed = 0.0
	
	if player.is_on_wall():
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
	if player.is_on_floor():
		speed_y = 0.0
		langtiao_timer = 0
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
		if abs(speed_x) > max_speed_x * 0.3:
			speed_y *= jump_speed_factor
		jumpable = false
		emit_signal("play_sound_jump")

	if player.is_on_ceiling():
		speed_y = 0.0
	
	var current_gravity = gravity_hold_jump if move_jump else gravity_normal
	if player_suit.power == PlayerSuit.PowerupType.LUI and player_suit.suit == PlayerSuit.SuitType.POWERED:
		current_gravity = gravity_hold_jump_lui if move_jump else gravity_normal_lui
	speed_y += current_gravity * delta

	# 限制垂直速度
	speed_y = minf(speed_y, max_speed_y)


	# 应用速度
	player.velocity = Vector2(-player.up_direction.y, player.up_direction.x) * speed_x - player.up_direction * speed_y
	player.move_and_slide()

	# 掉落桥检测
	platform_fall_detect()

	# 多重力
	on_triangle_block()

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

func update_hit_box() -> void:
	var is_super : bool
	if crouch or player_suit.suit == PlayerSuit.SuitType.SMALL:
		is_super = false
	else:
		is_super = true
	if not is_super:
		collision_shape.shape = shape_small
		collision_shape.position = Vector2(0, -1.5)
		cast.shape = shape_small
		cast.position = Vector2(0, -1.5)
	else:
		collision_shape.shape = shape_super
		collision_shape.position = Vector2(0, -16.5)
		cast.shape = shape_super
		cast.position = Vector2(0, -16.5)

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

func on_triangle_block() -> void:
	if is_switching_gravity:
		rotate_with_up = move_toward(rotate_with_up, target_gravity, 10.0)
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
		elif speed_x < -triangle_speed_x_limit:
			target_gravity += 90.0
			is_switching_gravity = true
