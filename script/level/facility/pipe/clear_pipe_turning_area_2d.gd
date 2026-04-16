extends Area2D

class_name ClearPipeTurningArea2D

@export var path_to_clear_pipe_set : NodePath = "../PipeDirectionSet"

var pipe_set : ClearPipeSet
var direction : ClearPipeSet.Direction = ClearPipeSet.Direction.LEFT
#var player_movement : PlayerMovement

func _ready() -> void:
	pipe_set = get_node(path_to_clear_pipe_set)
	direction = pipe_set.direction
	body_exited.connect(_on_body_exited)
	if process_mode == ProcessMode.PROCESS_MODE_DISABLED or not visible:
		queue_free()

func _on_body_exited(body : Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if has_meta("processed"):
		remove_meta("processed")