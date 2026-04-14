extends Area2D

class_name ClearPipeTurningArea2D

@export var path_to_clear_pipe_set : NodePath = "../PipeDirectionSet"

var pipe_set : ClearPipeSet
var direction : ClearPipeSet.Direction = ClearPipeSet.Direction.LEFT
#var player_movement : PlayerMovement

func _ready() -> void:
	pipe_set = get_node(path_to_clear_pipe_set)
	direction = pipe_set.direction
	if process_mode == ProcessMode.PROCESS_MODE_DISABLED or not visible:
		queue_free()
	#player_movement = get_tree().get_first_node_in_group("player").get_meta("player_movement") as PlayerMovement

func _physics_process(_delta: float) -> void:
	#if not player_movement.is_in_pipe:
	#	remove_meta("overlapped_with_player")

	if has_meta("overlapped_with_player"):
		for i in range(20):
			await get_tree().physics_frame
		remove_meta("overlapped_with_player")
