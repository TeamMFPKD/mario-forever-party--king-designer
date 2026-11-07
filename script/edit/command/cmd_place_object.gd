class_name CmdPlaceObject
extends Command

## 放置物件命令。
##
## 一次放置可能生成 1~2 个物件（门成对），还可能“顶掉”已有的 player
## （全局只能有一个 player）。命令保存的都是可重建的描述数据，
## undo 时销毁新建物件并恢复被顶掉的 player。

var _object_map: ObjectMapLayer = null
var _entries: Array[Dictionary] = []
var _replace_player: bool = false
var _replaced_player: Array[Dictionary] = []

static func create(object_map: ObjectMapLayer, entries: Array[Dictionary], replace_player: bool) -> CmdPlaceObject:
	if object_map == null or entries.is_empty():
		return null
	var command: CmdPlaceObject = CmdPlaceObject.new()
	command._object_map = object_map
	for entry: Dictionary in entries:
		command._entries.append(entry.duplicate(true))
	command._replace_player = replace_player
	return command

func get_display_name() -> String:
	if _entries.is_empty():
		return "PlaceObject"
	return "PlaceObject(%s)" % str(_entries[0].get("object_name", "?"))

func execute() -> void:
	if not is_valid():
		return
	if _replace_player:
		_replaced_player = _object_map.despawn_objects_of_type("player")
	_object_map.spawn_objects(_entries)

func undo() -> void:
	if not is_valid():
		return
	_object_map.despawn_objects(_entries)
	if not _replaced_player.is_empty():
		_object_map.spawn_objects(_replaced_player)

func is_valid() -> bool:
	return _object_map != null and is_instance_valid(_object_map)
