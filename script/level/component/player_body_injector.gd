extends Node

class_name PlayerBodyInjector

## 玩家注入器：作为 PlayerDependent 组件的子节点挂载，
## 延迟一帧查找玩家并调用目标的 inject_player_body()。

const PLAYER_GROUP: StringName = &"player"
const INJECT_METHOD: StringName = &"inject_player_body"

## 注入目标，默认父级（实现 PlayerDependent 的组件）
@export var inject_path: NodePath = ".."

## 找不到玩家时是否报错（标题演示等没有玩家的场景可关闭）
@export var warn_on_missing: bool = true

func _ready() -> void:
	# 延迟一帧：子节点 _ready 先于父节点，此时父组件与玩家都已完成入场
	_bind.call_deferred()

func _bind() -> void:
	if not is_inside_tree():
		return

	var target: Node = get_node_or_null(inject_path)
	if target == null:
		push_error("%s: 注入目标无效：%s (%s)" % [name, inject_path, _scene_location()])
		return
	if not target.has_method(INJECT_METHOD):
		push_error("%s: 目标没有 %s() (%s)" % [name, INJECT_METHOD, _scene_location()])
		return

	var body: Node2D = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if body == null:
		if warn_on_missing:
			push_error("%s: 组 \"%s\" 中找不到玩家 (%s)" % [name, PLAYER_GROUP, _scene_location()])
		return

	target.call(INJECT_METHOD, body)

## 定位所属场景，便于报错排查
func _scene_location() -> String:
	var node: Node = self
	while node != null:
		if not node.scene_file_path.is_empty():
			return "%s @ %s" % [node.scene_file_path, get_path()]
		node = node.get_parent()
	return str(get_path())
