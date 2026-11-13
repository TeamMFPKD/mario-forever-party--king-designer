extends Node

class_name ControlVisibieSet

## 显隐开关节点（被 tscn 连线调用 _set_visible / _set_invisible）。
##
## 两种情况：
## - 普通的子面板（设置页内部的设置 / 控制 / 制作人员、通知子项等）：直接改 visible。
## - 标题页的五个主页面：转调 TitlePageManager，由它负责"退出动画播完再隐藏"。
##   这样 tscn 里那一大批原有连线一行都不用改。

const PAGE_MANAGER_GROUP: StringName = &"title_page_manager"

@export var path_to_control: NodePath = ".."

var control: Control


func _ready() -> void:
	control = get_node(path_to_control) as Control


func _set_visible() -> void:
	var manager: Node = _page_manager()
	if manager != null and _manager_handles(manager):
		manager.call("open_page", control)
		return
	control.visible = true


func _set_invisible() -> void:
	var manager: Node = _page_manager()
	if manager != null and _manager_handles(manager):
		manager.call("close_page", control)
		return
	control.visible = false


## 标题页页面管理器；不在标题页（或还没就绪）时返回 null。
func _page_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(PAGE_MANAGER_GROUP)


func _manager_handles(manager: Node) -> bool:
	var result: Variant = manager.call("handles", control)
	if result is bool:
		var flag: bool = result
		return flag
	return false
