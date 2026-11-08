class_name LobbyService
extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 大厅与编辑房间的共享状态：加入 / 离开 / 准备 / 制作完毕 / 开局请求。
##
## 所有客户端 -> 主机的入口都用 get_remote_sender_id() 判定身份，
## 参数里不再携带 player_id，避免替别人改状态。

signal all_edit_finished
signal join_rejected(reason: String)

var _manager: MultiplayerManager
var _registry: SessionRegistry
var _net: NetPeer
var _last_roster_request_msec: int = 0


func setup(manager: MultiplayerManager, registry: SessionRegistry, net: NetPeer) -> void:
	_manager = manager
	_registry = registry
	_net = net
	if not _net.peer_left.is_connected(_on_peer_left):
		_net.peer_left.connect(_on_peer_left)


func send_join_request() -> void:
	if _net == null or _net.is_server():
		return
	var info: Dictionary = {
		"version": NetPeer.PROTOCOL_VERSION,
		"name": _manager.player.name,
		"avatar_id": _manager.player.avatar_id,
		"device_id": _manager.player.device_id,
	}
	c2s_join_room.rpc_id(1, info)


func set_lobby_ready(value: bool) -> void:
	if _net == null or _manager == null:
		return
	if _manager.phase != RoomPhase.Phase.LOBBY:
		return
	if _net.is_server():
		_apply_lobby_ready(_net.local_id(), value)
	else:
		c2s_set_lobby_ready.rpc_id(1, value)


func set_edit_finished(value: bool) -> void:
	if _net == null or _manager == null:
		return
	if _manager.phase != RoomPhase.Phase.EDIT:
		return
	if _net.is_server():
		_apply_edit_finished(_net.local_id(), value)
	else:
		c2s_set_edit_finished.rpc_id(1, value)


func request_start(edit_seconds: int) -> void:
	if _net == null or not _net.is_server():
		return
	if _manager.phase != RoomPhase.Phase.LOBBY:
		return
	Log.i(
		"MPTEST] all players ready count=%d" % _registry.size()
	)
	_manager.flow.start_edit(edit_seconds)


## 主机把某名玩家移出房间，并向所有客户端刷新名单。
func remove_player(id: int) -> PlayerProfile:
	if _net == null or not _net.is_server():
		return null
	var profile: PlayerProfile = _registry.remove(id)
	if profile != null:
		broadcast_snapshot()
	return profile


## 主机回到大厅时清空本局数据（保留身份）。客户端靠快照同步。
func reset_roster_for_lobby() -> void:
	if _net == null or not _net.is_server():
		return
	_registry.reset_match_state()
	broadcast_snapshot()


func broadcast_snapshot() -> void:
	if _net == null or not _net.is_server():
		return
	s2c_roster_snapshot.rpc(_registry.to_wire_list())


## 供其他服务下发单条玩家增量。
func broadcast_delta(profile: PlayerProfile) -> void:
	if profile == null:
		return
	_broadcast_delta(profile)


## 客户端主动拉一次全量名单（例如打开玩家列表时）。
func request_roster() -> void:
	if _net == null or _net.is_server() or not _net.is_online():
		return
	# 同一秒内多个 UI 节点同时请求时只发一次。
	var now: int = Time.get_ticks_msec()
	if now - _last_roster_request_msec < 1000:
		return
	_last_roster_request_msec = now
	c2s_request_roster.rpc_id(1)


func all_lobby_ready() -> bool:
	for profile: PlayerProfile in _registry.all():
		if not profile.lobby_ready:
			return false
	return not _registry.is_empty()


func everyone_edit_finished() -> bool:
	for profile: PlayerProfile in _registry.all():
		if not profile.edit_finished:
			return false
	return not _registry.is_empty()


func _apply_lobby_ready(id: int, value: bool) -> void:
	var profile: PlayerProfile = _registry.get_player(id)
	if profile == null:
		return
	profile.lobby_ready = value
	if value:
		Log.i("玩家 %s 已就绪" % [_manager.format_player(profile.name, profile.id)])
	else:
		Log.i("玩家 %s 未就绪" % [_manager.format_player(profile.name, profile.id)])
	_broadcast_delta(profile)
	if value and all_lobby_ready():
		Log.i("MPTEST] all players ready count=%d" % _registry.size())


func _apply_edit_finished(id: int, value: bool) -> void:
	var profile: PlayerProfile = _registry.get_player(id)
	if profile == null:
		return
	profile.edit_finished = value
	if value:
		Log.i("玩家 %s 已完成关卡编辑" % [_manager.format_player(profile.name, profile.id)])
	else:
		Log.i("玩家 %s 取消了完成编辑状态" % [_manager.format_player(profile.name, profile.id)])
	_broadcast_delta(profile)
	if everyone_edit_finished():
		Log.i("所有玩家都已完成关卡编辑，提前结束倒计时。")
		all_edit_finished.emit()


func _broadcast_delta(profile: PlayerProfile) -> void:
	if _net == null or not _net.is_server():
		return
	# c2s 处理是直接改 profile，不走 RPC 的 call_local；
	# 主机本地也必须发一次 players_updated，否则自己准备/编辑完成的状态不刷新。
	_registry.notify_changed(profile.id, PlayerProfile.GROUP_ALL)
	s2c_player_delta.rpc(profile.id, profile.to_wire())


func _on_peer_left(id: int, reason: String) -> void:
	var profile: PlayerProfile = _registry.get_player(id)
	if profile == null:
		return
	Log.w("玩家 %s — %s" % [_manager.format_player(profile.name, profile.id), reason])
	_registry.remove(id)
	broadcast_snapshot()
	if _manager.phase == RoomPhase.Phase.TRANSFER:
		_manager.levels.on_player_left(id)
	elif _manager.phase == RoomPhase.Phase.PLAY or _manager.phase == RoomPhase.Phase.RESULT:
		_manager.flow.on_player_left(id)


@rpc("any_peer", "call_remote", "reliable")
func c2s_join_room(info: Dictionary) -> void:
	if _net == null or not _net.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	if _manager.phase != RoomPhase.Phase.LOBBY:
		Log.w("拒绝加入：游戏已经开始")
		s2c_join_rejected.rpc_id(sender, "游戏已经开始，无法加入该房间。")
		_net.kick_peer(sender)
		return
	if int(info.get("version", -1)) != NetPeer.PROTOCOL_VERSION:
		Log.w("拒绝加入：协议版本不一致（%s）" % [str(info.get("version", -1))])
		s2c_join_rejected.rpc_id(sender, "客户端版本不一致，请更新后再加入。")
		_net.kick_peer(sender)
		return
	if _registry.has_player(sender):
		return

	var profile: PlayerProfile = PlayerProfile.new()
	profile.id = sender
	profile.name = str(info.get("name", "player")).substr(0, PlayerProfile.NAME_LIMIT)
	profile.avatar_id = str(info.get("avatar_id", ""))
	profile.device_id = str(info.get("device_id", ""))
	_registry.add(profile)
	Log.i("MPTEST] player joined name=%s id=%d" % [profile.name, profile.id])
	broadcast_snapshot()


@rpc("any_peer", "call_remote", "reliable")
func c2s_set_lobby_ready(value: bool) -> void:
	if _net == null or not _net.is_server():
		return
	if _manager.phase != RoomPhase.Phase.LOBBY:
		return
	_apply_lobby_ready(multiplayer.get_remote_sender_id(), value)


@rpc("any_peer", "call_remote", "reliable")
func c2s_set_edit_finished(value: bool) -> void:
	if _net == null or not _net.is_server():
		return
	if _manager.phase != RoomPhase.Phase.EDIT:
		return
	_apply_edit_finished(multiplayer.get_remote_sender_id(), value)


@rpc("authority", "call_remote", "reliable")
func s2c_roster_snapshot(list: Array) -> void:
	Log.i("MPTEST] roster snapshot received count=%d" % list.size())
	# replace_from_wire 会发 registry_reset，由门面统一转成 players_updated。
	_registry.replace_from_wire(list)


@rpc("authority", "call_remote", "reliable")
func s2c_player_delta(id: int, data: Dictionary) -> void:
	if not _registry.apply_wire(id, data):
		# 本地没有这个玩家：说明初始快照丢了。主动向主机要一次全量名单，
		# 否则后续所有增量都会被丢弃，列表永远是空的。
		Log.w("收到未知玩家 %d 的增量，请求全量名单" % id)
		c2s_request_roster.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func c2s_request_roster() -> void:
	if _net == null or not _net.is_server():
		return
	broadcast_snapshot()


@rpc("authority", "call_remote", "reliable")
func s2c_join_rejected(reason: String) -> void:
	Log.w("加入房间被拒绝：%s" % reason)
	join_rejected.emit(reason)
