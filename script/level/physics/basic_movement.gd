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

@export var is_clear_pipe_allowed : bool = false
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

func _ready() -> void:
	move_object = get_node(path_to_move_object) as CharacterBody2D
	player = get_tree().get_first_node_in_group("player") as Node2D
	var fc = func():
		player = get_tree().get_first_node_in_group("player") as Node2D
		if initially_face_to_player:
			set_movement_direction()
	fc.call_deferred()
	if overlap_turn:
		shape_cast = get_node_or_null(path_to_shape_cast) as ShapeCast2D
		if not shape_cast:
			push_error("BasicMovement: ShapeCast2D not found.")

	move_object.set_meta("basic_movement", self)

	if is_clear_pipe_allowed:
		ani = get_node_or_null(path_to_ani) as AnimatedSprite2D
		if not ani:
			for child in move_object.get_children():
				if child is AnimatedSprite2D:
					ani = child
					break
			if not ani:
				push_error("BasicMovement: AnimatedSprite2D not found.")
		var dusk_creator = dust_creator_scene.instantiate()
		pipe_entered.connect(dusk_creator.explode)
		pipe_exited.connect(dusk_creator.explode)

func _physics_process(delta: float) -> void:
	if pipe_check():
		pipe_movement()
		return
	if in_wall_process():
		return
	turn_detect()
	overlap_turn_detect()
	pipe_detect()
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
		if result is ClearPipeEntrance:
			continue
		if result == move_object:
			continue
		if result.has_meta("basic_movement"):
			var other_basic_movement_node = result.get_meta("basic_movement") as BasicMovement
			if not other_basic_movement_node.can_be_turn_overlap_detected:
				continue
		if !(result in overlap_turn_detect_objects):
			overlap_turn_detect_objects.append(result)
			speed_x *= -1.0

func speed_x_process() -> void:
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

# 返回 true 表示卡墙，外部应跳过本帧所有运动逻辑
func in_wall_process() -> bool:
	if move_object.move_and_collide(Vector2.ZERO, true, 0.08) != null:
		move_object.velocity = Vector2.ZERO
		# 一定时间后仍未挤出被判断为卡墙
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
	if speed_x == 0.0:
		return
	var results = ShapeCastQuery.shape_query(move_object, shape_cast)
	if results.size() <= 1:
		overlap_turn_detect_objects.clear()
		return
	for result in results:
		if not result is ClearPipeEntrance:
			continue
		if result == move_object:
			continue
		enter_pipe()

func enter_pipe() -> void:
	is_in_pipe = true

func exit_pipe() -> void:
	is_in_pipe = false

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
