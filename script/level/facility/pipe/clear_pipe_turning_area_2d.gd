extends Area2D

class_name ClearPipeTurningArea2D

@export var path_to_clear_pipe_set : NodePath = "../PipeDirectionSet"

var pipe_set : ClearPipeSet
var direction : ClearPipeSet.Direction = ClearPipeSet.Direction.LEFT

func _ready() -> void:
	pipe_set = get_node(path_to_clear_pipe_set)
	direction = pipe_set.direction
	#body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if has_meta("overlapped_with_player"):
		for i in range(20):
			await get_tree().physics_frame
		remove_meta("overlapped_with_player")

#func _on_body_entered(body: Node2D) -> void:
#	if not body.is_in_group("player"):
#		return
#	body.set_meta("clear_pipe_direction", direction)
