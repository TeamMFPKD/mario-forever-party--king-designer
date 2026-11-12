extends Area2D

class_name ClearPipeTurningArea2D

@export var path_to_clear_pipe_set: NodePath = "../PipeDirectionSet"

var pipe_set: ClearPipeSet
var direction: ClearPipeSet.Direction = ClearPipeSet.Direction.LEFT

# 记录每个实体是否已处理过转向
var processed_ids: Dictionary = {}

func _ready() -> void:
	if has_meta("processed"):
		remove_meta("processed")
	get_parent().set_meta("clear_pipe_turning_area", self)
	pipe_set = get_node(path_to_clear_pipe_set)
	direction = pipe_set.direction
	body_exited.connect(_on_body_exited)
	if process_mode == ProcessMode.PROCESS_MODE_DISABLED or not visible:
		queue_free()

func _exit_tree() -> void:
	# 父节点的 meta 指向自己；如果自己先被释放，meta 会变成悬空引用，
	# ClearPipeEntrance 之后再读到就会抛 "assign invalid previously freed instance"。
	var parent: Node = get_parent()
	if parent == null or not parent.has_meta("clear_pipe_turning_area"):
		return
	var raw: Variant = parent.get_meta("clear_pipe_turning_area")
	if not is_instance_valid(raw) or raw == self:
		parent.remove_meta("clear_pipe_turning_area")


func _on_body_exited(body: Node2D) -> void:
	var id: int = body.get_instance_id()
	processed_ids.erase(id)

func is_processed(body: Node2D) -> bool:
	return processed_ids.has(body.get_instance_id())

func mark_processed(body: Node2D) -> void:
	processed_ids[body.get_instance_id()] = true

func clear_processed(body: Node2D) -> void:
	processed_ids.erase(body.get_instance_id())