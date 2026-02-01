extends Node

class_name BasicMovement

@export var path_to_move_object: NodePath = ".."
var move_object : CharacterBody2D

@export var initially_face_to_player: bool = true
@export var speed_x: float = 1.0
@export var speed_y: float
@export var gravity: float = 0.5
@export var max_fall_speed: float = 999.0
@export var jump_speed: float
@export var edge_detect: bool = false

@export var overlap_turn : bool = true
@export var path_to_shape_cast: NodePath = "../BasicShapeCast2D"

var shape_cast

const FRAMERATE_ORIGIN: float = 50.0
var player: CharacterBody2D
var _not_in_wall: bool = false

var overlap_turn_detect_objects: Array[Node2D] = []

func _ready() -> void:
	move_object = get_node(path_to_move_object) as CharacterBody2D
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if initially_face_to_player:
		set_movement_direction()
	if overlap_turn:
		shape_cast = get_node(path_to_shape_cast) as ShapeCast2D

func _physics_process(delta: float) -> void:
	turn_detect()
	overlap_turn_detect()
	speed_x_process()
	speed_y_process()
	apply_speed()
	move()
	set_jump_speed()

func on_screen_entered() -> void:
	set_movement_direction()

func turn_detect() -> void:
	# 自动转向检测
	if edge_detect and move_object.is_on_floor():
		var origin_position = move_object.position
		move_object.position += Vector2(33.0 * sign(speed_x), 0.0)
		move_object.force_update_transform()
		# MoveAndCollide 的 safe_margin 参数必须为一个较小值，否则运动体会有约半截卡进地面边缘，原因未知
		var collision = move_object.move_and_collide(Vector2.DOWN * 20.0, true, 0.05)
		if collision == null:
			speed_x *= -1.0
		move_object.position = origin_position
		move_object.force_update_transform()

func overlap_turn_detect() -> void:
	if not overlap_turn_detect:
		return
	var results = ShapeCastQuery.shape_query(move_object, shape_cast)
	# exclude_parent 十大未解之谜
	print(results.size())
	if results.size() <= 1:
		overlap_turn_detect_objects.clear()
		return
	for result in results:
		if result == move_object:
			continue
		if !(result in overlap_turn_detect_objects):
			overlap_turn_detect_objects.append(result)
			speed_x *= -1.0

func speed_x_process() -> void:
	# x 速度
	if move_object.is_on_wall():
		speed_x *= -1.0

func speed_y_process() -> void:
	# y 速度
	# 重力微调
	if speed_y == 0.0:
		speed_y += gravity * 4
	
	if not move_object.is_on_floor():
		speed_y = clamp(speed_y + gravity, -999.0, max_fall_speed)

func apply_speed() -> void:
	move_object.velocity = Vector2(speed_x * FRAMERATE_ORIGIN, speed_y * FRAMERATE_ORIGIN)

func move() -> void:
	# 针对大部分敌人运动：卡墙处理
	if move_object.move_and_collide(Vector2.ZERO, true, 1.0) == null:
		var origin_position = move_object.position
		if not _not_in_wall:
			var obj = move_object
			var is_in_wall: bool = false

			obj.position += Vector2.UP * 1.0
			obj.velocity = Vector2.ZERO
			obj.move_and_slide()
			is_in_wall = obj.is_on_floor()
			obj.position = origin_position
			
			obj.position += Vector2.DOWN * 1.0
			obj.velocity = Vector2.ZERO
			obj.move_and_slide()
			is_in_wall = obj.is_on_ceiling() or is_in_wall
			obj.position = origin_position
			
			obj.velocity = Vector2.ZERO
			obj.move_and_slide()
			is_in_wall = obj.is_on_wall() or is_in_wall
			obj.position = origin_position
			
			obj.velocity = Vector2.ZERO
			obj.move_and_slide()
			is_in_wall = obj.is_on_wall() or is_in_wall
			obj.position = origin_position
			
			if is_in_wall:
				move_object.position = origin_position
			else:
				_not_in_wall = true
		else:
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
