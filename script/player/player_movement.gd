extends Node

@export var player : CharacterBody2D


@export var max_speed_x : float = 400.0
@export var acceleration : float = 600.0
@export var deceleration_ground : float = 800.0
@export var deceleration_air : float = 100.0

@export var jump_speed : float = 600
@export var jump_speed_factor : float = 1.1
@export var max_speed_y : float = 600

@export var gravity_normal = 2400
@export var gravity_hold_jump = 1250

var move_up : bool
var move_down : bool
var move_left : bool
var move_right : bool
var move_fire : bool
var move_jump : bool

var fire : String = "move_fire"
var jump : String = "move_jump"

var jumpable : bool
var jumpable_time : int = 15
var jumpable_timer : int

var speed_x : float
var speed_y : float

func _physics_process(delta):
	# 处理输入
	move_up = Input.is_action_pressed("move_up")
	move_down = Input.is_action_pressed("move_down")
	move_left = Input.is_action_pressed("move_left")
	move_right = Input.is_action_pressed("move_right")
	move_fire = Input.is_action_pressed("move_fire")
	move_jump = Input.is_action_pressed("move_jump")
	
	# 水平运动
	var target_speed = 0.0
	
	if player.is_on_wall():
		speed_x = 0.0

	# 确定目标速度方向
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
	if speed_y >= 0.0 and is_action_pressed(jump):
		jumpable = true
	if jumpable:
		jumpable_timer += 1
		if jumpable_timer > jumpable_time:
			jumpable = false
			jumpable_timer = 0
	if move_jump and jumpable and player.is_on_floor():
		speed_y = -jump_speed
		if abs(speed_x) > max_speed_x * 0.3:
			speed_y *= jump_speed_factor
		jumpable = false

	if player.is_on_ceiling():
		speed_y = 0.0
	
	speed_y += gravity_hold_jump * delta if move_jump else gravity_normal * delta
	
	# 限制垂直速度
	speed_y = minf(speed_y, max_speed_y)


	# 应用速度
	player.velocity = Vector2(speed_x, speed_y)
	player.move_and_slide()


func is_action_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)
