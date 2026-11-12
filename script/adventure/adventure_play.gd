extends Node2D

@warning_ignore_start("unsafe_call_argument", "unsafe_cast")

## 百人团游玩场景：清掉编辑/超时/截图等无关节点。
## 左侧关卡信息面板是场景自带的子节点 GameRoomSize/AdventureLevelInfo。
## 暂停菜单在子节点 AdventurePauseMenu（CanvasLayer，PROCESS_MODE_ALWAYS）。


func _ready() -> void:
	_remove_node("TimeoutManager")
	_remove_node("GameRoomSize/GameTimeHUD")
	_remove_node("GameRoomSize/MarginContainer")
	_remove_node("GameRoomSize/SubViewportContainer/SubViewport/RandomCapture")
	_remove_node("GameRoomSize/SubViewportContainer/SubViewport/Level/SaveLevel")
	Adventure.register_clear_transition(_find_clear_transition())


## 过关转场挂在关卡 SubViewport 里，按 640×480 的关卡坐标系播放。
func _find_clear_transition() -> CanvasLayer:
	return get_node_or_null("GameRoomSize/SubViewportContainer/SubViewport/AdventureClearTransition") as CanvasLayer


func _remove_node(path: String) -> void:
	var node: Node = get_node_or_null(path)
	if node != null:
		node.queue_free()
