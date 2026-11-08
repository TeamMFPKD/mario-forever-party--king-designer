class_name LevelTransferService
extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 关卡数据分发。
##
## 流程（全部由主机裁决）：
## 1. 主机进入 TRANSFER 后 begin_collect()，先读取自己的关卡文件；
## 2. 各客户端收到阶段广播后 submit_local_level()，分块发给主机；
## 3. 主机校验 SHA-256、落盘，再把同一份文件分块中继给其余客户端；
## 4. 每个客户端写盘成功后 ack，主机把该关卡标记为 level_ok；
## 5. 所有玩家 level_ok -> all_levels_ready。
##
## 传输失败/超时的玩家会被移出房间（用户确认的默认策略）。

signal all_levels_ready
signal progress_changed
signal player_failed(id: int, reason: String)

const CHUNK_SIZE: int = 32768
const MAX_LEVEL_SIZE: int = 16 * 1024 * 1024
const TRANSFER_TIMEOUT_MSEC: int = 45000

var _manager: MultiplayerManager
var _registry: SessionRegistry
var _net: NetPeer
var _lobby: LobbyService

## 主机侧：正在接收某个客户端的关卡。
var _incoming: Dictionary = {}
## 主机侧：已经收齐、正在中继给其他客户端的关卡。
var _relay: Dictionary = {}
## 主机侧：owner_id -> 截止时间（毫秒）。
var _deadlines: Dictionary = {}
## 客户端侧：正在接收主机中继过来的关卡。
var _client_incoming: Dictionary = {}


func setup(
	manager: MultiplayerManager,
	registry: SessionRegistry,
	net: NetPeer,
	lobby: LobbyService
) -> void:
	_manager = manager
	_registry = registry
	_net = net
	_lobby = lobby


func _process(_delta: float) -> void:
	if _net == null or not _net.is_server() or _deadlines.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var expired: Array[int] = []
	for owner: Variant in _deadlines.keys():
		var owner_id: int = int(owner)
		if now < int(_deadlines[owner]):
			continue
		if _incoming.has(owner_id) or _relay.has(owner_id):
			expired.append(owner_id)
	for owner_id: int in expired:
		_fail_owner(owner_id, "关卡传输超时")


## 主机进入 TRANSFER 阶段时调用。
func begin_collect() -> void:
	if _net == null or not _net.is_server():
		return
	_reset_transfer_state()
	var local: PlayerProfile = _manager.player
	var bytes: PackedByteArray = _read_local_level_bytes(local)
	if bytes.is_empty():
		Log.e("房主关卡文件缺失，无法开始传输")
		_manager.flow.abort_to_lobby("房主关卡文件缺失，已返回大厅。")
		return
	local.has_level = true
	local.level_file_name = _safe_level_path(local.level_file_name)
	_deadlines[local.id] = Time.get_ticks_msec() + TRANSFER_TIMEOUT_MSEC
	_broadcast_delta(local)
	Log.i("MPTEST] level submit id=%d bytes=%d" % [local.id, bytes.size()])
	_relay_level(local, bytes)
	progress_changed.emit()


## 客户端进入 TRANSFER 阶段后调用。
func submit_local_level() -> void:
	if _net == null or _net.is_server():
		return
	var local: PlayerProfile = _manager.player
	var bytes: PackedByteArray = _read_local_level_bytes(local)
	if bytes.is_empty():
		Log.e("本地关卡文件缺失，无法提交")
		c2s_level_failed.rpc_id(1, "本地关卡文件缺失")
		return
	var total_chunks: int = _chunk_count(bytes.size())
	var sha: String = _sha256(bytes)
	Log.i("MPTEST] level submit id=%d bytes=%d" % [local.id, bytes.size()])
	c2s_level_begin.rpc_id(1, local.level_file_name, bytes.size(), total_chunks, sha)
	for index: int in range(total_chunks):
		var begin: int = index * CHUNK_SIZE
		var end: int = mini(begin + CHUNK_SIZE, bytes.size())
		c2s_level_chunk.rpc_id(1, index, bytes.slice(begin, end))
	c2s_level_end.rpc_id(1)


func force_continue() -> void:
	if _net == null:
		return
	if _net.is_server():
		_check_all_levels_ready()
	else:
		c2s_transfer_poke.rpc_id(1)


## 有玩家离开时，主机清理相关传输状态；离开的玩家不再拖住流程。
func on_player_left(id: int) -> void:
	if _net == null or not _net.is_server():
		return
	_incoming.erase(id)
	_deadlines.erase(id)
	_relay.erase(id)
	for owner: Variant in _relay.keys():
		var owner_id: int = int(owner)
		var state: Dictionary = _relay[owner_id]
		var pending: Dictionary = state["pending"]
		pending.erase(id)
		if pending.is_empty():
			_mark_level_ok(owner_id)
	_check_all_levels_ready()


func _reset_transfer_state() -> void:
	_incoming.clear()
	_relay.clear()
	_deadlines.clear()
	_client_incoming.clear()


func _read_local_level_bytes(profile: PlayerProfile) -> PackedByteArray:
	var path: String = profile.level_file_name
	if not _is_safe_level_path(path):
		Log.e("关卡文件路径不合法：%s" % path)
		return PackedByteArray()
	if not FileAccess.file_exists(path):
		Log.e("关卡文件不存在：%s" % path)
		return PackedByteArray()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or bytes.size() > MAX_LEVEL_SIZE:
		Log.e("关卡文件大小异常：%d" % bytes.size())
		return PackedByteArray()
	return bytes


## 主机把某个玩家的关卡分块中继给其余所有客户端。
func _relay_level(owner: PlayerProfile, bytes: PackedByteArray) -> void:
	var pending: Dictionary = {}
	for profile: PlayerProfile in _registry.all():
		if profile.id == owner.id:
			continue
		if profile.id == _net.local_id() and _net.is_server():
			continue
		pending[profile.id] = true

	if pending.is_empty():
		_mark_level_ok(owner.id)
		return

	var total_chunks: int = _chunk_count(bytes.size())
	var sha: String = _sha256(bytes)
	_relay[owner.id] = {
		"file_name": owner.level_file_name,
		"sha": sha,
		"total_chunks": total_chunks,
		"pending": pending,
	}
	_deadlines[owner.id] = Time.get_ticks_msec() + TRANSFER_TIMEOUT_MSEC

	for peer_id: Variant in pending.keys():
		var target: int = int(peer_id)
		s2c_level_begin.rpc_id(target, owner.id, owner.level_file_name, total_chunks, sha)
		for index: int in range(total_chunks):
			var begin: int = index * CHUNK_SIZE
			var end: int = mini(begin + CHUNK_SIZE, bytes.size())
			s2c_level_chunk.rpc_id(target, owner.id, index, bytes.slice(begin, end))
		s2c_level_end.rpc_id(target, owner.id)


func _mark_level_ok(owner_id: int) -> void:
	var profile: PlayerProfile = _registry.get_player(owner_id)
	_deadlines.erase(owner_id)
	_relay.erase(owner_id)
	if profile == null:
		_check_all_levels_ready()
		return
	if profile.level_ok:
		_check_all_levels_ready()
		return
	profile.level_ok = true
	_broadcast_delta(profile)
	Log.i("MPTEST] level ready id=%d file=%s" % [owner_id, profile.level_file_name])
	progress_changed.emit()
	_check_all_levels_ready()


func _check_all_levels_ready() -> void:
	if _net == null or not _net.is_server():
		return
	if _registry.is_empty():
		return
	for profile: PlayerProfile in _registry.all():
		if not profile.level_ok:
			return
	Log.i("MPTEST] transfer complete count=%d" % _registry.size())
	all_levels_ready.emit()


func _fail_owner(owner_id: int, reason: String) -> void:
	if _net == null or not _net.is_server():
		return
	_deadlines.erase(owner_id)
	_incoming.erase(owner_id)
	_relay.erase(owner_id)
	if owner_id == _net.local_id():
		Log.e("房主关卡传输失败：%s" % reason)
		_manager.flow.abort_to_lobby("房主关卡数据异常，已返回大厅。")
		return
	var profile: PlayerProfile = _registry.get_player(owner_id)
	var display_name: String = "?" if profile == null else profile.name
	Log.e("玩家 %s 关卡传输失败：%s" % [display_name, reason])
	player_failed.emit(owner_id, reason)
	_lobby.remove_player(owner_id)
	_net.kick_peer(owner_id)
	_check_all_levels_ready()


func _broadcast_delta(profile: PlayerProfile) -> void:
	if _net == null or not _net.is_server():
		return
	# 通过 LobbyService 的权威通道下发，保持“只有主机能改名单”的规则。
	_lobby.broadcast_delta(profile)


func _chunk_count(size: int) -> int:
	return int(ceil(float(size) / float(CHUNK_SIZE)))


func _sha256(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


## 只接受 user:// 根目录下的 .lvl 文件，拒绝子目录与路径穿越。
func _is_safe_level_path(path: String) -> bool:
	if not path.begins_with("user://") or not path.ends_with(".lvl"):
		return false
	var relative: String = path.substr("user://".length())
	if relative.contains("..") or relative.contains("\\") or relative.contains(":"):
		return false
	return not relative.contains("/")


func _safe_level_path(path: String) -> String:
	if _is_safe_level_path(path):
		return path
	return ""


func _write_level_file(path: String, bytes: PackedByteArray, expected_sha: String = "") -> bool:
	if not _is_safe_level_path(path):
		Log.e("拒绝写入不合法路径：%s" % path)
		return false
	# 本机多开测试时所有实例共用 user://，同一份关卡会被多个进程同时写。
	# 内容已经一致就直接算成功，避免 Windows 文件锁互相打架。
	if _file_has_hash(path, expected_sha):
		return true

	# 临时文件名带进程号，避免两个实例抢同一个 .part。
	var tmp_path: String = "%s.%d.part" % [path, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		tmp_path = "%s.%d_%d.part" % [path, OS.get_process_id(), Time.get_ticks_usec()]
		file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		Log.e("无法写入临时文件：%s（%s）" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_buffer(bytes)
	file.close()

	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return false
	for _attempt: int in range(3):
		if FileAccess.file_exists(path):
			dir.remove(path)
		var error: int = dir.rename(tmp_path, path)
		if error == OK:
			return true
		# 同机其它实例可能已经先写入同一份内容，校验通过即可。
		if _file_has_hash(path, expected_sha):
			_remove_file(tmp_path)
			return true
		OS.delay_msec(40)

	_remove_file(tmp_path)
	Log.e("关卡文件落盘失败：%s" % path)
	return false


func _file_has_hash(path: String, expected_sha: String) -> bool:
	if expected_sha.is_empty() or not FileAccess.file_exists(path):
		return false
	var existing: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if existing.is_empty():
		return false
	return _sha256(existing) == expected_sha


func _remove_file(path: String) -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null and FileAccess.file_exists(path):
		dir.remove(path)


# ---------------------------------------------------------------------------
# 客户端 -> 主机：提交自己的关卡
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable", 2)
func c2s_level_begin(
	file_name: String,
	total_size: int,
	total_chunks: int,
	sha: String
) -> void:
	if _net == null or not _net.is_server():
		return
	if _manager.phase != RoomPhase.Phase.TRANSFER:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var profile: PlayerProfile = _registry.get_player(sender)
	if profile == null:
		return
	if _incoming.has(sender):
		return
	if not _is_safe_level_path(file_name):
		_fail_owner(sender, "关卡文件路径不合法")
		return
	if total_size <= 0 or total_size > MAX_LEVEL_SIZE:
		_fail_owner(sender, "关卡文件大小异常")
		return
	if total_chunks != _chunk_count(total_size) or total_chunks <= 0:
		_fail_owner(sender, "关卡分块数量异常")
		return
	_incoming[sender] = {
		"file_name": file_name,
		"total_size": total_size,
		"total_chunks": total_chunks,
		"sha": sha,
		"chunks": {},
		"received": 0,
	}
	_deadlines[sender] = Time.get_ticks_msec() + TRANSFER_TIMEOUT_MSEC


@rpc("any_peer", "call_remote", "reliable", 2)
func c2s_level_chunk(index: int, data: PackedByteArray) -> void:
	if _net == null or not _net.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _incoming.has(sender):
		return
	if _manager.phase != RoomPhase.Phase.TRANSFER:
		return
	var state: Dictionary = _incoming[sender]
	var total_chunks: int = int(state["total_chunks"])
	var total_size: int = int(state["total_size"])
	if index < 0 or index >= total_chunks:
		return
	var chunks: Dictionary = state["chunks"]
	if chunks.has(index):
		return
	if data.size() > CHUNK_SIZE:
		return
	if int(state["received"]) + data.size() > total_size:
		_fail_owner(sender, "关卡数据超出声明大小")
		return
	chunks[index] = data
	state["received"] = int(state["received"]) + data.size()
	_incoming[sender] = state


@rpc("any_peer", "call_remote", "reliable", 2)
func c2s_level_end() -> void:
	if _net == null or not _net.is_server():
		return
	if _manager.phase != RoomPhase.Phase.TRANSFER:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _incoming.has(sender):
		return
	var state: Dictionary = _incoming[sender]
	_incoming.erase(sender)
	var total_chunks: int = int(state["total_chunks"])
	var chunks: Dictionary = state["chunks"]
	if chunks.size() != total_chunks:
		_fail_owner(sender, "关卡分块不完整")
		return

	var bytes: PackedByteArray = PackedByteArray()
	for index: int in range(total_chunks):
		if not chunks.has(index):
			_fail_owner(sender, "关卡分块缺失")
			return
		var chunk: PackedByteArray = chunks[index]
		bytes.append_array(chunk)
	if bytes.size() != int(state["total_size"]):
		_fail_owner(sender, "关卡数据长度不一致")
		return
	if _sha256(bytes) != str(state["sha"]):
		_fail_owner(sender, "关卡数据校验失败")
		return
	var path: String = str(state["file_name"])
	if not _write_level_file(path, bytes, str(state["sha"])):
		_fail_owner(sender, "关卡文件写入失败")
		return

	var profile: PlayerProfile = _registry.get_player(sender)
	if profile == null:
		return
	profile.has_level = true
	profile.level_file_name = path
	_broadcast_delta(profile)
	Log.i("MPTEST] level received id=%d bytes=%d" % [sender, bytes.size()])
	progress_changed.emit()
	_relay_level(profile, bytes)


@rpc("any_peer", "call_remote", "reliable")
func c2s_level_failed(reason: String) -> void:
	if _net == null or not _net.is_server():
		return
	if _manager.phase != RoomPhase.Phase.TRANSFER:
		return
	_fail_owner(multiplayer.get_remote_sender_id(), reason)


@rpc("any_peer", "call_remote", "reliable")
func c2s_level_relay_ack(owner_id: int, ok: bool, reason: String) -> void:
	if _net == null or not _net.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _relay.has(owner_id):
		return
	var state: Dictionary = _relay[owner_id]
	var pending: Dictionary = state["pending"]
	if not pending.has(sender):
		return
	pending.erase(sender)
	state["pending"] = pending
	_relay[owner_id] = state
	if not ok:
		Log.e("客户端 %d 接收关卡 %d 失败：%s" % [sender, owner_id, reason])
		_fail_owner(owner_id, "客户端接收失败")
		return
	if pending.is_empty():
		_mark_level_ok(owner_id)


@rpc("any_peer", "call_remote", "reliable")
func c2s_transfer_poke() -> void:
	if _net == null or not _net.is_server():
		return
	_check_all_levels_ready()


# ---------------------------------------------------------------------------
# 主机 -> 客户端：中继关卡
# ---------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable", 2)
func s2c_level_begin(
	owner_id: int,
	file_name: String,
	total_chunks: int,
	sha: String
) -> void:
	if _net == null or _net.is_server():
		return
	if _manager.phase != RoomPhase.Phase.TRANSFER:
		return
	if not _is_safe_level_path(file_name):
		c2s_level_relay_ack.rpc_id(1, owner_id, false, "路径不合法")
		return
	if total_chunks <= 0:
		c2s_level_relay_ack.rpc_id(1, owner_id, false, "分块数量异常")
		return
	_client_incoming[owner_id] = {
		"file_name": file_name,
		"total_chunks": total_chunks,
		"sha": sha,
		"chunks": {},
	}


@rpc("authority", "call_remote", "reliable", 2)
func s2c_level_chunk(owner_id: int, index: int, data: PackedByteArray) -> void:
	if _net == null or _net.is_server():
		return
	if not _client_incoming.has(owner_id):
		return
	var state: Dictionary = _client_incoming[owner_id]
	var total_chunks: int = int(state["total_chunks"])
	if index < 0 or index >= total_chunks:
		return
	var chunks: Dictionary = state["chunks"]
	if chunks.has(index):
		return
	chunks[index] = data
	state["chunks"] = chunks
	_client_incoming[owner_id] = state


@rpc("authority", "call_remote", "reliable", 2)
func s2c_level_end(owner_id: int) -> void:
	if _net == null or _net.is_server():
		return
	if not _client_incoming.has(owner_id):
		return
	var state: Dictionary = _client_incoming[owner_id]
	_client_incoming.erase(owner_id)
	var total_chunks: int = int(state["total_chunks"])
	var chunks: Dictionary = state["chunks"]
	if chunks.size() != total_chunks:
		c2s_level_relay_ack.rpc_id(1, owner_id, false, "分块不完整")
		return
	var bytes: PackedByteArray = PackedByteArray()
	for index: int in range(total_chunks):
		if not chunks.has(index):
			c2s_level_relay_ack.rpc_id(1, owner_id, false, "分块缺失")
			return
		var chunk: PackedByteArray = chunks[index]
		bytes.append_array(chunk)
	if _sha256(bytes) != str(state["sha"]):
		c2s_level_relay_ack.rpc_id(1, owner_id, false, "校验失败")
		return
	var path: String = str(state["file_name"])
	if not _write_level_file(path, bytes, str(state["sha"])):
		c2s_level_relay_ack.rpc_id(1, owner_id, false, "写入失败")
		return
	c2s_level_relay_ack.rpc_id(1, owner_id, true, "")
	Log.i("MPTEST] level cached id=%d" % owner_id)
	progress_changed.emit()
