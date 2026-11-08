extends Node

## 玩家离开 / 与主机断开 → 统一交给 MessageOverlay 的左下角气泡堆叠显示。
## 外观沿用旧的「玩家离开提示」纯文字样式（见 MessageBubble.setup_system），
## 动画与快捷消息共用同一套滑入、停留、淡出和 8 条上限。


func _ready() -> void:
	MPManager.registry.player_removed.connect(_on_player_removed)
	MPManager.net.server_lost.connect(_on_server_lost)


func _on_player_removed(_id: int, display_name: String) -> void:
	_show_system_message(tr("玩家离开提示").format({"player_name": display_name}))


func _on_server_lost() -> void:
	_show_system_message(tr("与主机断开。"))


func _show_system_message(text: String) -> void:
	var overlay: Node = get_node_or_null("/root/MessageOverlay")
	if overlay == null:
		return
	overlay.call("show_system_message", text)
