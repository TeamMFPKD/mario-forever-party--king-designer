extends Node

## 玩家离开 / 掉线 / 与主机断开 → 统一交给 MessageOverlay 的左下角气泡堆叠显示。
## 外观沿用旧的「玩家离开提示」纯文字样式（见 MessageBubble.setup_system），
## 动画与快捷消息共用同一套滑入、停留、淡出和 8 条上限。
##
## 名单变更（被移出房间）由 registry.player_removed 驱动：主机端在 remove 时发出，
## 客户端（含观看者）由 SessionRegistry.replace_from_wire 的名称对比补发。
## 意外掉线（记录还留在名单里、只把 connected 置 false）没有 remove 事件，
## 因此这里额外盯 connected 的跳变，保证所有人都能看到掉线文字。

## 上一次看到的每名玩家连接状态，用于识别「刚加入」与「刚才还在、现在掉线」。
var _connected_state: Dictionary[int, bool] = {}
## 第一次拿到名单只记录不提示：进房时已经在场的人不算「刚加入」。
var _state_initialized: bool = false


func _ready() -> void:
	MPManager.registry.player_removed.connect(_on_player_removed)
	MPManager.net.server_lost.connect(_on_server_lost)
	MPManager.players_updated.connect(_on_players_updated)
	MPManager.local_player_left.connect(_on_local_player_left)
	_sync_connection_state()


func _on_local_player_left(display_name: String) -> void:
	_show_system_message(tr("玩家离开提示").format({"player_name": display_name}))


func _on_player_removed(_id: int, display_name: String) -> void:
	_show_system_message(tr("玩家离开提示").format({"player_name": display_name}))


func _on_server_lost() -> void:
	_show_system_message(tr("与主机断开。"))


func _on_players_updated() -> void:
	_sync_connection_state()


## 主机端靠 notify_changed、客户端靠名单快照，都会走到 players_updated，
## 所以两端用同一套状态跳变判断：新出现的 id = 加入，true -> false = 掉线。
func _sync_connection_state() -> void:
	var current: Dictionary[int, bool] = {}
	for profile: PlayerProfile in MPManager.players:
		current[profile.id] = profile.connected
		var known: bool = _connected_state.has(profile.id)
		if not known and profile.connected:
			# 自己的加入也要有消息；别人的首次名单（进房时已经在场）保持静默。
			if profile.id == MPManager.player.id or _state_initialized:
				_show_system_message(tr("玩家加入提示").format({"player_name": profile.name}))
			continue
		# 掉线：刚才还连着、现在断开才提示；已经断开的不重复弹。
		if known and _connected_state[profile.id] and not profile.connected:
			_show_system_message(tr("玩家掉线提示").format({"player_name": profile.name}))
	_connected_state = current
	# 名单清空（离开房间 / 断线）后，下一次填充要重新静默。
	_state_initialized = not current.is_empty()


func _show_system_message(text: String) -> void:
	var overlay: Node = get_node_or_null("/root/MessageOverlay")
	if overlay == null:
		return
	overlay.call("show_system_message", text)
