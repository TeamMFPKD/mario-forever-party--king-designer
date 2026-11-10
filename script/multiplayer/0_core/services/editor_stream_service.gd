extends Node

@warning_ignore_start("unsafe_call_argument")

## 编辑器观战截图流（方案 C）。
##
## 目标编辑器只抓关卡 SubViewport 的 480×360 / JPEG 画面；主机负责把
## “观战者 -> 目标”的订阅关系转达给目标，目标只向订阅者 rpc_id 推帧。
## 所有 RPC 都在 /root/MPManager/EditorStreamService 这个稳定节点上。

signal frame_received(jpeg: PackedByteArray)

const CAPTURE_WIDTH: int = 480
const CAPTURE_HEIGHT: int = 360
const JPEG_QUALITY: float = 0.65
const MAX_FRAME_BYTES: int = 512 * 1024

var _manager: MultiplayerManager

## 目标端：正在看我编辑器的观战者 peer id。
var _subscribers: Dictionary[int, bool] = {}
## 主机端：观战者 peer id -> 目标玩家 id。
var _watch_targets: Dictionary[int, int] = {}
## 观战端：当前订阅的玩家 id。
var _remote_target_id: int = 0
## 目标端：帧序号；观战端用它丢弃乱序的旧帧。
var _frame_id: int = 0
var _last_frame_id: int = 0


func setup(manager: MultiplayerManager) -> void:
	_manager = manager
	_manager.phase_changed.connect(_on_phase_changed)
	_manager.players_updated.connect(_prune_watchers)


func has_subscribers() -> bool:
	return not _subscribers.is_empty()


## 观战端调用：订阅/切换目标。target_id = 0 表示取消订阅。
func request_watch(target_id: int) -> void:
	_remote_target_id = target_id
	_last_frame_id = 0
	if _manager == null or _manager.net == null or not _manager.net.is_online():
		return
	if _manager.net.is_server():
		_host_set_watch(_manager.net.local_id(), target_id)
	else:
		c2s_request_watch.rpc_id(1, target_id)


func clear_local_watch() -> void:
	_remote_target_id = 0
	_last_frame_id = 0
	if _manager == null or _manager.net == null or not _manager.net.is_online():
		return
	if _manager.net.is_server():
		if _watch_targets.has(_manager.net.local_id()):
			_host_set_watch(_manager.net.local_id(), 0)
	else:
		c2s_request_watch.rpc_id(1, 0)


func push_frame(image: Image) -> void:
	if image == null or _subscribers.is_empty():
		return
	var resized: Image = image.duplicate() as Image
	if resized == null:
		return
	resized.resize(CAPTURE_WIDTH, CAPTURE_HEIGHT, Image.INTERPOLATE_BILINEAR)
	var jpeg: PackedByteArray = resized.save_jpg_to_buffer(JPEG_QUALITY)
	if jpeg.is_empty() or jpeg.size() > MAX_FRAME_BYTES:
		return
	_frame_id += 1
	for raw_spectator_id: Variant in _subscribers.keys():
		s2c_editor_frame.rpc_id(int(raw_spectator_id), _frame_id, jpeg)


func _on_phase_changed(phase: int, _payload: Dictionary) -> void:
	if phase != RoomPhase.Phase.EDIT:
		_clear_all()


func _prune_watchers() -> void:
	if not _is_host():
		return
	for raw_spectator_id: Variant in _watch_targets.keys().duplicate():
		var spectator_id: int = int(raw_spectator_id)
		var spectator: PlayerProfile = _manager.registry.get_player(spectator_id)
		var target_id: int = int(_watch_targets.get(spectator_id, 0))
		var target: PlayerProfile = _manager.registry.get_player(target_id)
		if spectator == null or target == null or target.is_spectator:
			_host_set_watch(spectator_id, 0)


func _clear_all() -> void:
	if _is_host():
		for raw_spectator_id: Variant in _watch_targets.keys().duplicate():
			var spectator_id: int = int(raw_spectator_id)
			_remove_subscriber(int(_watch_targets[spectator_id]), spectator_id)
		_watch_targets.clear()
	_subscribers.clear()
	_remote_target_id = 0
	_frame_id = 0
	_last_frame_id = 0


func _host_set_watch(spectator_id: int, target_id: int) -> void:
	if not _is_host():
		return
	var old_target: int = int(_watch_targets.get(spectator_id, 0))
	if old_target == target_id:
		return
	if old_target != 0:
		_remove_subscriber(old_target, spectator_id)
		_watch_targets.erase(spectator_id)
	if target_id <= 0:
		return
	var target: PlayerProfile = _manager.registry.get_player(target_id)
	if target == null or target.is_spectator:
		return
	_watch_targets[spectator_id] = target_id
	_add_subscriber(target_id, spectator_id)
	Log.i("EditorStream", "观战者 %d 订阅玩家 %d 的编辑器" % [spectator_id, target_id])


func _add_subscriber(target_id: int, spectator_id: int) -> void:
	var target: PlayerProfile = _manager.registry.get_player(target_id)
	if target == null:
		return
	if _is_host() and target_id == _manager.net.local_id():
		_subscribers[spectator_id] = true
	else:
		s2c_add_subscriber.rpc_id(target_id, spectator_id)


func _remove_subscriber(target_id: int, spectator_id: int) -> void:
	var target: PlayerProfile = _manager.registry.get_player(target_id)
	if target == null:
		return
	if _is_host() and target_id == _manager.net.local_id():
		_subscribers.erase(spectator_id)
	else:
		s2c_remove_subscriber.rpc_id(target_id, spectator_id)


func _is_host() -> bool:
	return _manager != null and _manager.net != null and _manager.net.is_server()


# ---------------------------------------------------------------------------
# RPC
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func c2s_request_watch(target_id: int) -> void:
	if not _is_host():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var spectator: PlayerProfile = _manager.registry.get_player(sender)
	if spectator == null or not spectator.is_spectator:
		return
	_host_set_watch(sender, target_id)


@rpc("authority", "call_remote", "reliable")
func s2c_add_subscriber(spectator_id: int) -> void:
	_subscribers[spectator_id] = true


@rpc("authority", "call_remote", "reliable")
func s2c_remove_subscriber(spectator_id: int) -> void:
	_subscribers.erase(spectator_id)


@rpc("any_peer", "call_remote", "unreliable")
func s2c_editor_frame(frame_id: int, jpeg: PackedByteArray) -> void:
	if jpeg.is_empty() or jpeg.size() > MAX_FRAME_BYTES:
		return
	if _remote_target_id == 0:
		return
	if frame_id <= _last_frame_id:
		return
	if multiplayer.get_remote_sender_id() != _remote_target_id:
		return
	_last_frame_id = frame_id
	frame_received.emit(jpeg)
