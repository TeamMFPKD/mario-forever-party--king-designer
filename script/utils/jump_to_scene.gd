extends Node

## 通用场景跳转节点。
##
## 进入关卡/编辑器时，来源房间（如"喜欢的关卡"）会把自己的场景路径写进 LevelPathSet 的
## return_scene_path；use_return_scene 为 true 的跳转节点优先回到那个房间，而不是 scene_uid。

const LEVEL_PATH_SET_GROUP: String = "level_path_set"
const RETURN_SCENE_META: String = "return_scene_path"

@export var scene_uid: StringName
@export var use_return_scene: bool = false

func jump_to_scene() -> void:
	GlobalTransition.change_scene_to_file(_resolve_scene())

func _resolve_scene() -> String:
	var fallback: String = String(scene_uid)
	if not use_return_scene:
		return fallback
	var level_path_set: Node = get_tree().get_first_node_in_group(LEVEL_PATH_SET_GROUP)
	if level_path_set == null:
		return fallback
	var return_path: String = str(level_path_set.get_meta(RETURN_SCENE_META, ""))
	if return_path.is_empty():
		return fallback
	# 一次性消费：离开关卡/编辑器后不再影响后续跳转
	level_path_set.remove_meta(RETURN_SCENE_META)
	Log.i("JumpToScene", "返回进入关卡前的房间：%s" % return_path)
	return return_path
