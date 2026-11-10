class_name LobbyService
extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 大厅与编辑房间的共享状态：加入 / 离开 / 准备 / 制作完毕 / 开局请求。
##
## 所有客户端 -> 主机的入口都用 get_remote_sender_id() 判定身份，
## 参数里不再携带 player_id，避免替别人改状态。

signal all_edit_finished
signal join_rejected(reason: String)

## 掉线后保留玩家记录的宽限期。宽限内重连按 device_id 恢复；超时标记 abandoned。
const RECONNECT_GRACE_MSEC: int = 20000

var _manager: MultiplayerManager
var _registry: SessionRegistry
var _net: NetPeer
var _last_roster_request_msec: int = 0
var _abandoned_notified: Dictionary[int, bool] = {}


func _process(_delta: float) -> void:
	if _net == null or not _net.is_server():
		return
	var now: int = Time.get_ticks_msec()
	for profile: PlayerProfile in _registry.all():
		if profile.connected or profile.abandoned:
			continue
		if now - profile.disconnected_at_msec < RECONNECT_GRACE_MSEC:
			continue
		profile.abandoned = true
		# 不再等待这名玩家的输入；结果页仍保留他的成绩行。
		profile.reach_end = true
		_registry.notify_changed(profile.id, PlayerProfile.GROUP_ALL)
		broadcast_snapshot()
		if _abandoned_notified.has(profile.id):
			continue
		_abandoned_notified[profile.id] = true
		Log.w("玩家 %s 重连超时，已标记离线" % _manager.format_player(profile.name, profile.id))
		if _manager.phase == RoomPhase.Phase.TRANSFER:
			_manager.levels.on_player_left(profile.id)
		elif _manager.phase == RoomPhase.Phase.PLAY \
		or _manager.phase == RoomPhase.Phase.RESULT:
			_manager.flow.on_player_left(profile.id)


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
		"is_spectator": _manager.player.is_spectator,
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


## 大厅内切换“游戏 / 观战”。只有 LOBBY 阶段允许，开局后角色锁定。
func set_spectator(value: bool) -> void:
	if _net == null or _manager == null:
		return
	if _manager.phase != RoomPhase.Phase.LOBBY:
		return
	if _net.is_server():
		_apply_spectator(_net.local_id(), value)
	else:
		c2s_set_spectator.rpc_id(1, value)


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
	if playing_count() <= 0:
		Notice.show_notice("至少需要 1 名游玩玩家才能开始。", "无法开始")
		return
	Log.i(
		"MPTEST] all players ready count=%d" % playing_count()
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
	var count: int = 0
	for profile: PlayerProfile in _registry.all():
		if profile.is_spectator:
			continue
		count += 1
		if not profile.lobby_ready:
			return false
	return count > 0


func everyone_edit_finished() -> bool:
	var count: int = 0
	for profile: PlayerProfile in _registry.all():
		if profile.is_spectator:
			continue
		count += 1
		if not profile.edit_finished:
			return false
	return count > 0


## 正式参与本局的玩家（不含观战者）。
func playing_profiles() -> Array[PlayerProfile]:
	var result: Array[PlayerProfile] = []
	for profile: PlayerProfile in _registry.all():
		if profile.is_spectator:
			continue
		result.append(profile)
	return result


func playing_count() -> int:
	return playing_profiles().size()


func spectator_count() -> int:
	return _registry.size() - playing_count()


func _apply_lobby_ready(id: int, value: bool) -> void:
	var profile: PlayerProfile = _registry.get_player(id)
	if profile == null or profile.is_spectator:
		return
	profile.lobby_ready = value
	if value:
		Log.i("玩家 %s 已就绪" % [_manager.format_player(profile.name, profile.id)])
	else:
		Log.i("玩家 %s 未就绪" % [_manager.format_player(profile.name, profile.id)])
	_broadcast_delta(profile)
	if value and all_lobby_ready():
		Log.i("MPTEST] all players ready count=%d" % _registry.size())


func _apply_spectator(id: int, value: bool) -> void:
	var profile: PlayerProfile = _registry.get_player(id)
	if profile == null:
		return
	if profile.is_spectator == value:
		return
	# 已准备后锁定参与模式；必须先取消准备才能切观战/游戏。
	if profile.lobby_ready:
		return
	profile.is_spectator = value
	if value:
		# 转观战后不再占用准备/编辑名额。
		profile.lobby_ready = false
		profile.edit_finished = false
	_broadcast_delta(profile)
	Log.i(
		"玩家 %s 切换为%s"
		% [_manager.format_player(profile.name, profile.id), "观战" if value else "游戏"]
	)


func _apply_edit_finished(id: int, value: bool) -> void:
	var profile: PlayerProfile = _registry.get_player(id)
	if profile == null or profile.is_spectator:
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
	# 主动退出：不保留 20s 宽限，立即清理。
	if reason == "主动退出" or reason == "房主关闭房间":
		_registry.remove(id)
		_abandoned_notified.erase(id)
		broadcast_snapshot()
		if _manager.phase == RoomPhase.Phase.TRANSFER:
			_manager.levels.on_player_left(id)
		elif _manager.phase == RoomPhase.Phase.PLAY or _manager.phase == RoomPhase.Phase.RESULT:
			_manager.flow.on_player_left(id)
		return
	# 意外断开：保留记录 20s，等待同 device_id 重连。
	profile.connected = false
	profile.disconnected_at_msec = Time.get_ticks_msec()
	_registry.notify_changed(id, PlayerProfile.GROUP_ALL)
	broadcast_snapshot()
	Log.i("等待玩家 %s 在 %d 秒内重连" % [
		profile.name, int(RECONNECT_GRACE_MSEC / 1000.0),
	])


func _find_disconnected(device_id: String, player_name: String) -> PlayerProfile:
	if device_id.is_empty():
		return null
	for profile: PlayerProfile in _registry.all():
		if profile.connected or profile.abandoned:
			continue
		if profile.device_id == device_id and profile.name == player_name:
			return profile
	return null


func _make_profile(sender: int, info: Dictionary) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.id = sender
	profile.name = str(info.get("name", "player")).substr(0, PlayerProfile.NAME_LIMIT)
	profile.avatar_id = str(info.get("avatar_id", ""))
	profile.device_id = str(info.get("device_id", ""))
	profile.is_spectator = bool(info.get("is_spectator", false))
	profile.connected = true
	return profile


## 同 device_id 的玩家在 20s 内重新连上：换 peer id，保留关卡/成绩/角色。
func _restore_profile(profile: PlayerProfile, sender: int) -> void:
	var old_id: int = profile.id
	_registry.remove(old_id)
	_abandoned_notified.erase(old_id)
	profile.id = sender
	profile.connected = true
	profile.abandoned = false
	profile.disconnected_at_msec = 0
	_registry.add(profile)
	broadcast_snapshot()
	Log.i(
		"玩家 %s 已重连：%d -> %d（%s）"
		% [
			profile.name, old_id, sender,
			"观战" if profile.is_spectator else "游玩",
		]
	)
	_manager.flow.s2c_sync_phase_to(sender)
	if _manager.phase == RoomPhase.Phase.TRANSFER:
		_manager.levels.resume_for(sender)
	elif _manager.phase == RoomPhase.Phase.PLAY:
		_manager.levels.relay_all_to(sender)


@rpc("any_peer", "call_remote", "reliable")
func c2s_join_room(info: Dictionary) -> void:
	if _net == null or not _net.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	if _registry.has_player(sender):
		return
	if int(info.get("version", -1)) != NetPeer.PROTOCOL_VERSION:
		Log.w("拒绝加入：协议版本不一致（%s）" % [str(info.get("version", -1))])
		s2c_join_rejected.rpc_id(sender, "客户端版本不一致，请更新后再加入。")
		_net.kick_peer(sender)
		return

	var wants_spectator: bool = bool(info.get("is_spectator", false))
	var device_id: String = str(info.get("device_id", ""))
	var reconnect_name: String = str(info.get("name", ""))

	# 1) 掉线重连：同 device_id + 同名、20s 宽限内，保留原角色与进度。
	var disconnected: PlayerProfile = _find_disconnected(device_id, reconnect_name)
	if disconnected != null:
		_restore_profile(disconnected, sender)
		return

	# 2) 游戏已开始：只有观战角色可以加入；游玩角色请重连或等下一局。
	if _manager.phase != RoomPhase.Phase.LOBBY and not wants_spectator:
		Log.w("拒绝加入：游戏已经开始（name=%s）" % str(info.get("name", "?")))
		s2c_join_rejected.rpc_id(sender, "游戏已开始，只能以观战身份加入。")
		_net.kick_peer(sender)
		return

	var profile: PlayerProfile = _make_profile(sender, info)
	_registry.add(profile)
	Log.i(
		"MPTEST] player joined name=%s id=%d role=%s"
		% [profile.name, profile.id, "观战" if profile.is_spectator else "游玩"]
	)
	broadcast_snapshot()
	if _manager.phase != RoomPhase.Phase.LOBBY:
		# 中途加入的观战者：同步当前阶段；传输/游玩阶段顺手拿全量关卡。
		_manager.flow.s2c_sync_phase_to(sender)
		if _manager.phase == RoomPhase.Phase.TRANSFER \
		or _manager.phase == RoomPhase.Phase.PLAY:
			_manager.levels.relay_all_to(sender)


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


@rpc("any_peer", "call_remote", "reliable")
func c2s_set_spectator(value: bool) -> void:
	if _net == null or not _net.is_server():
		return
	if _manager.phase != RoomPhase.Phase.LOBBY:
		return
	_apply_spectator(multiplayer.get_remote_sender_id(), value)


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
