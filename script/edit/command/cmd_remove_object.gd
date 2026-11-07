class_name CmdRemoveObject
extends Command

## 删除物件命令（橡皮擦）。
##
## 门会成组删除（同一 door_id 的所有门），删除前把描述数据保存下来，
## undo 时按 object_name / position / door_id 重新实例化。

var _object_map: ObjectMapLayer = null
var _targets: Array[Dictionary] = []
var _removed: Array[Dictionary] = []

static func create(object_map: ObjectMapLayer, targets: Array[Dictionary]) -> CmdRemoveObject:
	if object_map == null or targets.is_empty():
		return null
	var command: CmdRemoveObject = CmdRemoveObject.new()
	command._object_map = object_map
	for target: Dictionary in targets:
		command._targets.append(target.duplicate(true))
	return command

func get_display_name() -> String:
	if _targets.is_empty():
		return "RemoveObject"
	return "RemoveObject(%s)" % str(_targets[0].get("object_name", "?"))

func execute() -> void:
	if not is_valid():
		return
	_removed = _object_map.despawn_objects(_targets)

func undo() -> void:
	if not is_valid():
		return
	_object_map.spawn_objects(_removed)

func is_valid() -> bool:
	return _object_map != null and is_instance_valid(_object_map)
