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

func _on_body_entered(body : Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("enter_pipe"):
		body.enter_pipe()
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
