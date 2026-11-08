extends Node

## 玩家离开 / 与主机断开 → 统一交给 MessageOverlay 的左下角气泡堆叠显示。
## 外观沿用旧的「玩家离开提示」纯文字样式（见 MessageBubble.setup_system），
## 动画与快捷消息共用同一套滑入、停留、淡出和 8 条上限。

var multiplayer_manager: MultiplayerManager
var players: Array = []
var previous_players: Array = []


func _ready() -> void:
	multiplayer_manager = MPManager
	multiplayer_manager.players_updated.connect(_on_players_updated)
	multiplayer_manager.multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_players_updated() -> void:
	if previous_players.size() == 0:
		previous_players = players
	players = multiplayer_manager.players
	if players.size() != previous_players.size():
		_on_players_changed()
	previous_players = players


func _on_players_changed() -> void:
	# 只关注玩家离开的情况
	if players.size() >= previous_players.size():
		return
	for prev_player: Dictionary in previous_players:
		var found: bool = false
		for player: Dictionary in players:
			if player.id == prev_player.id:
				found = true
				break
		if not found:
			_show_system_message(
				tr("玩家离开提示").format({"player_name": prev_player.name})
			)


func _on_server_disconnected() -> void:
	_show_system_message(tr("与主机断开。"))


func _show_system_message(text: String) -> void:
	var overlay: Node = get_node_or_null("/root/MessageOverlay")
	if overlay == null:
		return
	overlay.call("show_system_message", text)
