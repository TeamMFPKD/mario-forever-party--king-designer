class_name CmdMoveObject
extends Command

## 拖动物件命令。
##
## 拖动过程中 ObjectMapLayer 已经实时更新了节点位置（所见即所得），
## 松手时用 push_executed_command() 把本命令压栈，所以 execute() 不会
## 在首次入栈时被调用；只有 redo 才会再次调用。
##
## 定位方式：object_name + 目标格坐标（门额外带 door_id）。
## 不保存节点引用，避免 undo 链条中对象被重建后引用失效。

var _object_map: ObjectMapLayer = null
var _object_name: String = ""
var _door_id: int = -1
var _from_position: Vector2 = Vector2.ZERO
var _to_position: Vector2 = Vector2.ZERO

static func create(
		object_map: ObjectMapLayer,
		object_name: String,
		door_id: int,
		from_position: Vector2,
		to_position: Vector2
) -> CmdMoveObject:
	if object_map == null or object_name == "" or from_position == to_position:
		return null
	var command: CmdMoveObject = CmdMoveObject.new()
	command._object_map = object_map
	command._object_name = object_name
	command._door_id = door_id
	command._from_position = from_position
	command._to_position = to_position
	return command

func get_display_name() -> String:
	return "MoveObject(%s)" % _object_name

func execute() -> void:
	if not is_valid():
		return
	_object_map.move_object_by_description(_object_name, _door_id, _from_position, _to_position)

func undo() -> void:
	if not is_valid():
		return
	_object_map.move_object_by_description(_object_name, _door_id, _to_position, _from_position)

func is_valid() -> bool:
	return _object_map != null and is_instance_valid(_object_map)
