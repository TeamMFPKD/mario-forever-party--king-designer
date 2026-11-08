class_name NetPeer
extends Node

## 传输层：唯一直接操作 multiplayer.multiplayer_peer 的地方。
##
## 负责 ENet 生命周期、连接超时、断线原因，不碰玩家资料、关卡数据或 UI。
## 所有房间流程通过下面的信号驱动。

signal hosted
signal joined
signal connect_failed(reason: String)
signal server_lost
signal room_closed
signal peer_left(id: int, reason: String)
signal state_changed(state: int)

enum State {
	OFFLINE = 0,
	HOSTING = 1,
	CONNECTING = 2,
	CONNECTED = 3,
	DISCONNECTING = 4,
}

const PROTOCOL_VERSION: int = 1
const PORT_MIN: int = 1
const PORT_MAX: int = 65535
const JOIN_TIMEOUT_MSEC: int = 10000
const DEFAULT_MAX_CLIENTS: int = 20

var _state: int = State.OFFLINE
var _join_deadline_msec: int = 0
var _disconnect_reasons: Dictionary = {}


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(_delta: float) -> void:
	if _state != State.CONNECTING or _join_deadline_msec == 0:
		return
	if Time.get_ticks_msec() < _join_deadline_msec:
		return
	_join_deadline_msec = 0
	Log.w("连接主机超时（%d 毫秒），主动放弃本次连接" % JOIN_TIMEOUT_MSEC)
	_force_offline()
	connect_failed.emit("连接超时，未能连接到主机。")


func state() -> int:
	return _state


func is_server() -> bool:
	if _state == State.HOSTING:
		return true
	return _state == State.CONNECTED and multiplayer.is_server()


func is_online() -> bool:
	return _state == State.HOSTING or _state == State.CONNECTED


func is_connecting() -> bool:
	return _state == State.CONNECTING


func local_id() -> int:
	return multiplayer.get_unique_id()


func host(port: int) -> int:
	if not is_valid_port(port):
		return ERR_INVALID_PARAMETER
	if is_online():
		return ERR_ALREADY_IN_USE

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_server(port, DEFAULT_MAX_CLIENTS)
	if error != OK:
		Log.e("创建服务器失败（本地端口 %d）：%s" % [port, error_string(error)])
		return error

	multiplayer.multiplayer_peer = peer
	_join_deadline_msec = 0
	_set_state(State.HOSTING)
	hosted.emit()
	return OK


func join(address: String, port: int) -> int:
	if not is_valid_port(port):
		return ERR_INVALID_PARAMETER
	if is_online() or is_connecting():
		return ERR_ALREADY_IN_USE

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(address, port)
	if error != OK:
		Log.e("加入房间失败（%s:%d）：%s" % [address, port, error_string(error)])
		return error

	multiplayer.multiplayer_peer = peer
	_join_deadline_msec = Time.get_ticks_msec() + JOIN_TIMEOUT_MSEC
	_set_state(State.CONNECTING)
	return OK


## 主动断开。不触发 server_lost。
func leave() -> void:
	_join_deadline_msec = 0
	if _state == State.OFFLINE:
		return
	_set_state(State.DISCONNECTING)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_state(State.OFFLINE)


func kick_peer(id: int) -> void:
	if not is_server():
		return
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		var enet: ENetMultiplayerPeer = peer
		enet.disconnect_peer(id)


func is_valid_port(port: int) -> bool:
	return port >= PORT_MIN and port <= PORT_MAX


## 主机关房：先广播，再本地断开。call_local 让主机自己也走同一套清理。
func close_room() -> void:
	if not is_server():
		leave()
		return
	s2c_server_closing.rpc()


func _force_offline() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_state(State.OFFLINE)


func _set_state(value: int) -> void:
	if _state == value:
		return
	_state = value
	state_changed.emit(_state)


func _on_connected_to_server() -> void:
	_join_deadline_msec = 0
	_set_state(State.CONNECTED)
	joined.emit()


func _on_connection_failed() -> void:
	if _state == State.OFFLINE:
		return
	_join_deadline_msec = 0
	_force_offline()
	connect_failed.emit("无法连接到主机。")


func _on_server_disconnected() -> void:
	if _state == State.OFFLINE or _state == State.DISCONNECTING:
		return
	_force_offline()
	server_lost.emit()


func _on_peer_disconnected(id: int) -> void:
	if not is_server():
		return
	var reason: String = "意外断开连接"
	if _disconnect_reasons.has(id):
		reason = str(_disconnect_reasons[id])
		_disconnect_reasons.erase(id)
	peer_left.emit(id, reason)


@rpc("any_peer", "call_remote", "reliable")
func c2s_leave_reason(reason: String) -> void:
	if not is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_disconnect_reasons[sender] = reason


@rpc("authority", "call_local", "reliable")
func s2c_server_closing() -> void:
	Log.i("服务器即将关闭")
	leave()
	room_closed.emit()
