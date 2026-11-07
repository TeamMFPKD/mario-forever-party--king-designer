class_name CmdPipeLine
extends Command

## 透明管道折线命令（新建 / 拖动 / 删除共用）。
##
## before_points 为空 = 新建；after_points 为空 = 删除；两者都有 = 改点集。
## 折线本身没有稳定 ID，用点集内容定位（所有点都对齐 32 网格，可精确比较）。

var _pipe_draw: Node = null
var _before_points: Array[Vector2] = []
var _after_points: Array[Vector2] = []

static func create(pipe_draw: Node, before_points: Array[Vector2], after_points: Array[Vector2]) -> CmdPipeLine:
	if pipe_draw == null or not is_instance_valid(pipe_draw):
		return null
	if _same_points(before_points, after_points):
		return null
	if before_points.size() < 2 and after_points.size() < 2:
		return null
	var command: CmdPipeLine = CmdPipeLine.new()
	command._pipe_draw = pipe_draw
	command._before_points = before_points.duplicate()
	command._after_points = after_points.duplicate()
	return command

static func _same_points(a: Array[Vector2], b: Array[Vector2]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

func get_display_name() -> String:
	if _before_points.size() < 2:
		return "AddPipeLine"
	if _after_points.size() < 2:
		return "RemovePipeLine"
	return "MovePipeLine"

func execute() -> void:
	if not is_valid():
		return
	if _after_points.size() < 2:
		_remove_line(_before_points)
	elif _before_points.size() < 2:
		_add_line(_after_points)
	else:
		_set_line(_before_points, _after_points)

func undo() -> void:
	if not is_valid():
		return
	if _before_points.size() < 2:
		_remove_line(_after_points)
	elif _after_points.size() < 2:
		_add_line(_before_points)
	else:
		_set_line(_after_points, _before_points)

func is_valid() -> bool:
	return _pipe_draw != null and is_instance_valid(_pipe_draw)

func _find_line(points: Array[Vector2]) -> int:
	var result: Variant = _pipe_draw.call("find_line_index_by_points", points)
	if result is int:
		return result
	if result is float:
		var result_float: float = result
		return int(result_float)
	return -1

func _add_line(points: Array[Vector2]) -> void:
	var index: int = _find_line(points)
	if index >= 0:
		_pipe_draw.call("set_line_points_at", index, points)
	else:
		_pipe_draw.call("add_line_from_points", points)
	_pipe_draw.call("rebuild_pipes")

func _remove_line(points: Array[Vector2]) -> void:
	var index: int = _find_line(points)
	if index < 0:
		return
	_pipe_draw.call("remove_line", index)
	_pipe_draw.call("rebuild_pipes")

func _set_line(from_points: Array[Vector2], to_points: Array[Vector2]) -> void:
	var index: int = _find_line(from_points)
	if index < 0:
		return
	_pipe_draw.call("set_line_points_at", index, to_points)
	_pipe_draw.call("rebuild_pipes")
