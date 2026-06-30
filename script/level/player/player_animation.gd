extends Node

signal play_sound_skid

@export var ani : AnimatedSprite2D
@export var player_movement : PlayerMovement
@export var player_suit : PlayerSuit
@export var player : CharacterBody2D
@export var player_hurt_and_die : PlayerHurtAndDie

@export var player_lui_effect_scene : PackedScene

@export_group("player_spritesframe")
@export var player_small_spritesframe : SpriteFrames
@export var player_super_spritesframe : SpriteFrames
@export var player_fireball_spritesframe : SpriteFrames
@export var player_beetroot_spritesframe : SpriteFrames
@export var player_lui_spritesframe : SpriteFrames
@export var player_big_spritesframe: SpriteFrames
@export var player_bee_spritesframe : SpriteFrames
@export var player_cloud_spritesframe : SpriteFrames

var current_state : String = "idle"
var last_direction : int = 1  # 1表示向右，-1表示向左
var walk_animation_frame : int = 0  # 记录walk动画的当前帧

var turn : bool = false

var hurt_timer : int = 0

var is_appearing : bool = false
@export var appear_time : int = 80
var appear_timer : int = 0

func _physics_process(_delta: float):
	update_animation()

func update_animation():
	var new_state = determine_state()
	var direction = determine_direction()

	# Hurt Effect
	if player_hurt_and_die.is_hurting:
		hurt_timer += 1
		ani.visible = hurt_timer % 2 == 0
	else:
		ani.visible = true
		hurt_timer = 0
	
	# Pipe Scale
	var scale_speed : float = 0.1
	ani.scale = ani.scale.move_toward(Vector2(0.5, 0.5) if is_in_pipe() else Vector2(1.0, 1.0), scale_speed)

	if new_state != current_state or direction != last_direction:
		# 保存当前walk动画的进度
		if current_state == "walk" and ani.animation == "walk":
			walk_animation_frame = ani.frame
		
		current_state = new_state
		last_direction = direction
		
		# 设置动画
		if ani.sprite_frames.has_animation(current_state):
			ani.animation = current_state
			
			# 如果是切换回walk动画，恢复之前的进度
			if current_state == "walk" and ani.animation == "walk":
				ani.frame = walk_animation_frame
			
			# 根据状态设置动画速度
			update_animation_speed()
			
			ani.play()
	else:
		# 即使状态没有改变，也要更新动画速度（比如速度变化时）
		update_animation_speed()
		
		# 持续记录walk动画的当前帧
		if current_state == "walk" and ani.animation == "walk":
			walk_animation_frame = ani.frame
	
	# 根据重力方向旋转精灵
	#ani.rotation_degrees = player_movement.rotate_with_up

	# 设置方向
	if player.is_on_floor():
		ani.flip_h = (direction == -1)
	else:
		if player_movement.move_left:
			ani.flip_h = true
		elif player_movement.move_right:
			ani.flip_h = false

	# WEEGEE effect
	if (new_state == "jump" or new_state == "crouch") \
	and !player.is_on_floor() \
	and player_suit.suit == PlayerSuit.SuitType.POWERED and player_suit.power == PlayerSuit.PowerupType.LUI:
		var lui_effect = player_lui_effect_scene.instantiate() as Node2D
		lui_effect.position = player.position
		lui_effect.rotation = player.rotation
		var lui_ani = lui_effect.get_node("AnimatedSprite2D")
		lui_ani.animation = new_state
		lui_ani.frame = ani.frame
		lui_ani.flip_h = ani.flip_h
		player.add_sibling(lui_effect)

# 根据角色状态和速度更新动画播放速度
func update_animation_speed():
	match current_state:
		"walk":
			# 行走动画速度与水平速度挂钩
			var speed_factor = abs(player_movement.speed_x) / player_movement.max_speed_x
			# 基础速度 + 速度比例，确保最小播放速度
			ani.speed_scale = 1.0 + speed_factor * 5.0
		_:
			# 其他状态使用正常速度
			ani.speed_scale = 1.0

func determine_state() -> String:
	if is_appearing:
		appear_timer += 1
		if appear_timer >= appear_time:
			appear_timer = 0
			is_appearing = false
		return "appear"

	# 检查是否在水管中
	if is_in_pipe():
		return "jump"
		
	# 检查是否在游泳状态
	if is_in_water():
		return "swim"
	
	# 检查是否在下蹲
	if player_movement.crouch:
		return "crouch"
	
	# 检查跳跃状态
	if !player.is_on_floor():
		return "jump"
	
	# 检查行走状态
	if current_state != "turn" \
	or (
		#abs(player_movement.speed_x) <= player_movement.max_speed_x * 0.7 or \
		sign(player_movement.speed_x) == sign(player_movement.target_speed)
	):
		turn = false

	if abs(player_movement.speed_x) > 0.0 and !player.is_on_wall():
		if sign(player_movement.speed_x) != sign(player_movement.target_speed) \
		and abs(player_movement.speed_x) > player_movement.max_speed_x * 0.5 \
		and (player_movement.move_left or player_movement.move_right) \
		or turn:
			turn = true
			emit_signal("play_sound_skid")
			return "turn"
		else:
			return "walk"
	
	# 默认空闲状态
	return "idle"

func determine_direction() -> int:
	if player_movement.is_in_pipe:
		match player_movement.pipe_moving_dir:
			PlayerMovement.PipeMoveDirection.LEFT:
				return -1
			PlayerMovement.PipeMoveDirection.RIGHT:
				return 1
		# 根据水平速度确定方向
	if player_movement.speed_x > 0:
		return 1
	elif player_movement.speed_x < 0:
		return -1
	else:
		# 如果没有水平移动，保持上次的方向
		return last_direction

func is_in_water() -> bool:
	# 暂时返回false
	return false

func _on_player_suit_changed():
	match player_suit.suit:
		PlayerSuit.SuitType.SMALL:
			ani.sprite_frames = player_small_spritesframe
		PlayerSuit.SuitType.SUPER:
			ani.sprite_frames = player_super_spritesframe
		PlayerSuit.SuitType.POWERED:
			match player_suit.power:
				PlayerSuit.PowerupType.FIREBALL:
					ani.sprite_frames = player_fireball_spritesframe
				PlayerSuit.PowerupType.BEETROOT:
					ani.sprite_frames = player_beetroot_spritesframe
				PlayerSuit.PowerupType.LUI:
					ani.sprite_frames = player_lui_spritesframe
				PlayerSuit.PowerupType.BIG:
					ani.sprite_frames = player_big_spritesframe
				PlayerSuit.PowerupType.BEE:
					ani.sprite_frames = player_bee_spritesframe
				PlayerSuit.PowerupType.CLOUD:
					ani.sprite_frames = player_cloud_spritesframe
	is_appearing = true

func is_in_pipe() -> bool:
	return player_movement.is_in_pipe