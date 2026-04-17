extends Area2D

class_name ClearPipeTurningArea2D

@export var path_to_clear_pipe_set : NodePath = "../PipeDirectionSet"

var pipe_set : ClearPipeSet
var direction : ClearPipeSet.Direction = ClearPipeSet.Direction.LEFT

# 记录每个实体是否已处理过转向
var processed_ids : Dictionary = {}

func _ready() -> void:
	pipe_set = get_node(path_to_clear_pipe_set)
	direction = pipe_set.direction
	body_exited.connect(_on_body_exited)
	if process_mode == ProcessMode.PROCESS_MODE_DISABLED or not visible:
		queue_free()

func _on_body_exited(body : Node2D) -> void:
	var id = body.get_instance_id()
	processed_ids.erase(id)

func is_processed(body: Node2D) -> bool:
	return processed_ids.has(body.get_instance_id())

func mark_processed(body: Node2D) -> void:
	processed_ids[body.get_instance_id()] = true

func clear_processed(body: Node2D) -> void:
	processed_ids.erase(body.get_instance_id())