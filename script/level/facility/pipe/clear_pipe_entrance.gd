extends Area2D

class_name ClearPipeEntrance

@export var path_to_clear_pipe_set : NodePath = "../PipeDirectionSet"
@export var path_to_turning : NodePath = "../ClearPipeTurningArea2D"

enum Direction {
	LEFT,
	RIGHT,
	UP,
	DOWN,
}
@export var entrance_direction : Direction = Direction.LEFT

var clear_pipe_set : ClearPipeSet
var turning_area : Area2D

func _ready() -> void:
	clear_pipe_set = get_node(path_to_clear_pipe_set)
	body_entered.connect(_on_body_entered)
	turning_area = get_node(path_to_turning)
	if process_mode == ProcessMode.PROCESS_MODE_DISABLED or not visible:
		queue_free()

func _physics_process(_delta: float) -> void:
	var blocks = get_overlapping_bodies()
	position = position
	if blocks.size() > 0:
		set_meta("overlapping_with_block", true)
	else:
		if has_meta("overlapping_with_block"):
			remove_meta("overlapping_with_block")
	if has_meta("overlapped_with_player"):
		for i in range(6):
			await get_tree().physics_frame
		remove_meta("overlapped_with_player")

func _on_body_entered(body : Node2D) -> void:
	if not body.is_in_group("player"):
		return
	#if body.has_method("enter_pipe"):
	#	body.enter_pipe()
	var direction
	match clear_pipe_set.direction:
		ClearPipeSet.Direction.LEFT:
			direction = PlayerMovement.PipeMoveDirection.RIGHT
		ClearPipeSet.Direction.RIGHT:
			direction = PlayerMovement.PipeMoveDirection.LEFT
		ClearPipeSet.Direction.UP:
			direction = PlayerMovement.PipeMoveDirection.DOWN
		ClearPipeSet.Direction.DOWN:
			direction = PlayerMovement.PipeMoveDirection.UP
	body.set_meta("clear_pipe_direction", direction)