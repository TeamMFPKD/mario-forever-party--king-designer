extends BasicMovement

signal play_sound_shoot

@export var path_to_parent : NodePath = ".."
@export var projectile_scene : PackedScene = preload("uid://3ieotv447ssg")
@export var solid_area : Area2D
@export var ani : AnimatedSprite2D
@export var launch_offset : Vector2 = Vector2(0, 0)

@export var walk_time : int = 50
@export var shoot_time : int = 36
@export var wait_after_shoot_time : int = 36
@export var bro_jump_speed : float = -700.0
@export var bro_slight_jump_speed : float = -80.0
@export var walking_distance : float = 48.0

enum BroState {
	WALK,
	SLIGHT_JUMP,
	JUMP,
	SHOOT,
	WAIT_AFTER_SHOOT,
}

var bro_state : BroState = BroState.WALK

var parent : Node2D
var walk_timer : int
var shoot_timer : int = 0
var wait_after_shoot_timer : int = 0
var origin_collision_mask
var origin_position_x : float
var origin_speed_x : float
var direction : int = -1

var slight_jumped : bool
var jumped : bool

var rng = RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	parent = get_node(path_to_parent)
	origin_collision_mask = move_object.collision_mask
	origin_position_x = move_object.position.x
	origin_speed_x = abs(speed_x)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	print(self.name, bro_state)

	# Movement
	var move_x : bool = bro_state == BroState.WALK or bro_state == BroState.SLIGHT_JUMP
	speed_x = origin_speed_x * direction if move_x else 0.0

	# 越你爷爷
	# ——梗取自 SMBX
	if move_object.position.x > origin_position_x + walking_distance:
		direction = -1
	elif move_object.position.x < origin_position_x - walking_distance:
		direction = 1

	match bro_state:
		BroState.WALK:
			walk_timer += 1
			if walk_timer >= walk_time:
				walk_timer = 0
				select_state()
		BroState.SLIGHT_JUMP:
			if speed_y > 0.0:
				move_object.collision_mask = origin_collision_mask
			if move_object.is_on_floor() and slight_jumped:
				select_state()
				return
			if move_object.is_on_floor() and not slight_jumped:
				speed_y = bro_slight_jump_speed
				slight_jumped = true
				move_object.collision_mask = 0
		BroState.JUMP:
			# TODO: Jump down
			if speed_y >= 0.0 and solid_area.get_overlapping_bodies().size() == 0 and jumped:
				move_object.collision_mask = origin_collision_mask
				if move_object.is_on_floor():
					select_state()
					return
			if move_object.is_on_floor() and not jumped:
				speed_y = bro_jump_speed
				move_object.collision_mask = 0
				jumped = true
		BroState.SHOOT:
			shoot_timer += 1
			ani.play("shoot")
			if shoot_timer >= shoot_time:
				shoot_timer = 0
				launch()
				bro_state = BroState.WAIT_AFTER_SHOOT
				ani.play("default")
		BroState.WAIT_AFTER_SHOOT:
			wait_after_shoot_timer += 1
			if wait_after_shoot_timer >= wait_after_shoot_time:
				wait_after_shoot_timer = 0
				select_state()

func select_state() -> void:
	var states = BroState.values()
	slight_jumped = false
	jumped = false
	bro_state = states[rng.randi_range(0, states.size() - 1)]

func launch() -> void:
	var left : bool = player.position.x < parent.position.x

	var projectile = projectile_scene.instantiate() as Node2D
	projectile.position = parent.position + launch_offset
	projectile.set_meta("fireball_direction", -1 if left else 1)
	parent.add_sibling(projectile)

	emit_signal("play_sound_shoot")

func set_jump_speed() -> void:
	# 重写是为防止在地面上 y 速度被 jump_speed 设置覆盖
	pass
