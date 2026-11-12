extends BasicMovement

signal play_sound_shoot

@export var path_to_parent: NodePath = ".."
@export var projectile_scene: PackedScene = preload("uid://3ieotv447ssg")
@export var solid_area: Area2D
@export var launch_offset: Vector2 = Vector2(0, 0)

@export var walk_time: int = 50
@export var shoot_time: int = 36
@export var wait_after_shoot_time: int = 36
@export var bro_jump_speed: float = -700.0
@export var bro_slight_jump_speed: float = -80.0
@export var walking_distance: float = 48.0

enum BroState {
	WALK,
	SLIGHT_JUMP,
	JUMP_UP,
	JUMP_DOWN,
	SHOOT,
	WAIT_AFTER_SHOOT,
}

var bro_state: BroState = BroState.WALK

var parent: Node2D
var walk_timer: int
var shoot_timer: int = 0
var wait_after_shoot_timer: int = 0
var origin_collision_mask: int
var origin_position_x: float
var origin_speed_x: float
var direction: int = -1

var slight_jumped: bool
var jumped: bool

var previous_position_y: float
var jump_level: int

## 关掩码时记下的起跳 x：恢复掩码前若已嵌进地形，用它把身体拉回墙外。
var mask_disabled: bool = false
var jump_origin_x: float

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	parent = get_node(path_to_parent)
	origin_collision_mask = move_object.collision_mask
	origin_position_x = move_object.position.x
	origin_speed_x = abs(speed_x)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Movement
	var move_x: bool = bro_state == BroState.WALK or bro_state == BroState.SLIGHT_JUMP
	speed_x = origin_speed_x * direction if move_x else 0.0

	# Debug
	#print("Bro State: ", bro_state)
	#print("Bro speed y: ", speed_y)

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
				_restore_collision_mask()
			if move_object.is_on_floor() and slight_jumped:
				select_state()
				return
			if move_object.is_on_floor() and not slight_jumped:
				speed_y = bro_slight_jump_speed
				slight_jumped = true
				_disable_collision_mask()
				move()
		BroState.JUMP_UP:
			#print("why still on floor! 1")
			if speed_y >= 0.0 and solid_area.get_overlapping_bodies().size() == 0 and jumped:
				_restore_collision_mask()
				if move_object.is_on_floor():
					if previous_position_y - move_object.position.y > 48:
						jump_level += 1
					select_state()
					return
			#print("why still on floor! 2")
			if move_object.is_on_floor() and not jumped:
				speed_y = bro_jump_speed
				_disable_collision_mask()
				jumped = true
				previous_position_y = move_object.position.y
				move()
				#print("why still on floor! 3 bro jump speed: ", speed_y)
		BroState.JUMP_DOWN:
			if jump_level <= 0:
				select_state()
				return
			if speed_y >= abs(bro_slight_jump_speed) * 2 \
			and solid_area.get_overlapping_bodies().size() == 0 and jumped:
				_restore_collision_mask()
				if move_object.is_on_floor():
					jump_level -= 1
					select_state()
					return
			if move_object.is_on_floor() and not jumped:
				speed_y = bro_slight_jump_speed
				_disable_collision_mask()
				jumped = true
				previous_position_y = move_object.position.y
				move()
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

	# 兜底：这三个状态以外没人管掩码，若还残留关着就继续尝试恢复，防止带着 mask=0 穿出关卡。
	if mask_disabled and bro_state != BroState.SLIGHT_JUMP \
	and bro_state != BroState.JUMP_UP and bro_state != BroState.JUMP_DOWN:
		_restore_collision_mask()

## 关闭碰撞掩码并记下起跳点（起跳瞬间一定没嵌进地形，可作安全锚点）。
func _disable_collision_mask() -> void:
	if not mask_disabled:
		jump_origin_x = move_object.position.x
		mask_disabled = true
	move_object.collision_mask = 0

## 恢复碰撞掩码。若恢复时身体已经嵌进砖块（小跳期间横向漂进了墙里），
## 先把水平位置退回起跳点再试；仍嵌着就继续关掩码等下一帧，避免被
## BasicMovement.in_wall_process() 的一帧重叠直接判成挤死。
func _restore_collision_mask() -> void:
	move_object.collision_mask = origin_collision_mask
	if not mask_disabled:
		return
	if _is_overlapping_solid():
		move_object.position.x = jump_origin_x
		move_object.force_update_transform()
		if _is_overlapping_solid():
			move_object.collision_mask = 0
			return
	mask_disabled = false

## 用形状查询判断"恢复掩码后是否会嵌进地形"。
## 不用 move_and_collide(Vector2.ZERO)：同一物理帧内刚 move_and_slide 过，
## 物理服务器里的身体状态可能还是移动前的，偶发漏判（实测 45 秒漏 1 次）。
func _is_overlapping_solid() -> bool:
	var shape_node: CollisionShape2D = move_object.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		for child: Node in move_object.get_children():
			if child is CollisionShape2D:
				shape_node = child as CollisionShape2D
				break
	if shape_node == null or shape_node.shape == null:
		return false
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = origin_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [move_object.get_rid()]
	var hits: Array[Dictionary] = move_object.get_world_2d().direct_space_state.intersect_shape(query, 1)
	return not hits.is_empty()

func select_state() -> void:
	if mask_disabled:
		_restore_collision_mask()
	var states: Array = BroState.values()
	slight_jumped = false
	jumped = false
	bro_state = states[rng.randi_range(0, states.size() - 1)]

func launch() -> void:
	var left: bool = player.position.x < parent.position.x

	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	projectile.position = parent.position + launch_offset
	projectile.set_meta("fireball_direction", -1 if left else 1)
	parent.add_sibling(projectile)

	emit_signal("play_sound_shoot")

func set_jump_speed() -> void:
	# 重写是为防止在地面上 y 速度被 jump_speed 设置覆盖
	pass
