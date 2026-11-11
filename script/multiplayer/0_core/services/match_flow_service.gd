class_name MatchFlowService
extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 主机权威的房间阶段机。
##
## 客户端不自己判断何时切场景，只接受 s2c_phase_changed 并跟随。
## 各客户端的关卡索引进度按用户确认保持“各玩各的”，这里只负责阶段与结算聚合。

signal phase_changed(phase: int, payload: Dictionary)
signal result_updated(results: Array)

const SCENE_READY: String = "uid://ci7x1alix6g2"
const SCENE_TRANSFER: String = "uid://brg4yepawdra3"
const SCENE_PLAY: String = "uid://cxvueju65b3qv"
const SCENE_RESULT: String = "uid://c0civs02iqoki"
const SCENE_TITLE: String = "uid://dcqf1c3m14b1f"
## 观战者不进入玩家房间，统一留在独立观战场景，按阶段刷新内容。
const SCENE_SPECTATE: String = "res://room/spectate_room.tscn"

const RESULT_TIMEOUT_SEC: float = 120.0
## ready_room 的准备动画时长；主机侧权威计时必须把它算进去。
const READY_COUNTDOWN_SEC: float = 5.5

var phase: int = RoomPhase.Phase.NONE
var random_levels: Array[String] = []
var current_level_count: int = 0
var edit_seconds: int = 0
## 最近一次结算数据。结算场景可能在广播之后才加载，result_list 在 _ready 里补读。
var last_results: Array = []

var _manager: MultiplayerManager
var _registry: SessionRegistry
var _net: NetPeer
var _lobby: LobbyService
## 主机权威的编辑阶段计时。房主自己观战时没有编辑房间，
## 必须由本服务在超时后推进 TRANSFER。
var _host_edit_timer: Timer


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
	_host_edit_timer = Timer.new()
	_host_edit_timer.name = "HostEditTimer"
	_host_edit_timer.one_shot = true
	_host_edit_timer.timeout.connect(_on_host_edit_timeout)
	add_child(_host_edit_timer)


func _on_host_edit_timeout() -> void:
	if _net == null or not _net.is_server():
		return
	if phase != RoomPhase.Phase.EDIT:
		return
	finish_edit("倒计时结束")


## 主机在标题页点“开始”。
func start_edit(seconds: int) -> void:
	if _net == null or not _net.is_server():
		return
	if phase != RoomPhase.Phase.LOBBY:
		return
	edit_seconds = seconds
	current_level_count = 0
	random_levels.clear()
	_manager.game_start_time = _make_match_stamp()
	Log.i("MPTEST] phase EDIT edit_seconds=%d" % seconds)
	s2c_phase_changed.rpc(
		RoomPhase.Phase.EDIT,
		{
			"edit_seconds": seconds,
			"stamp": _manager.game_start_time,
		}
	)
	if _net.is_server():
		# 准备动画 5.5s 之后玩家才开始编辑；主机权威计时同样从 Start 开始算。
		# 编辑器直接运行时 ready_room 会跳过动画，这里也要跳过这段等待。
		var ready_sec: float = 0.0 if OS.has_feature("editor") else READY_COUNTDOWN_SEC
		_host_edit_timer.start(ready_sec + float(seconds))


## 编辑倒计时结束或全员完成编辑（仅主机调用）。
func finish_edit(reason: String) -> void:
	if _net == null or not _net.is_server():
		return
	if phase != RoomPhase.Phase.EDIT:
		return
	if _host_edit_timer != null:
		_host_edit_timer.stop()
	var timer: Timer = TimerSingleton
	if timer != null and not timer.is_stopped():
		timer.stop()
	Log.i("主机：%s！进入关卡传输阶段。" % reason)
	Log.i("MPTEST] phase TRANSFER")
	s2c_phase_changed.rpc(RoomPhase.Phase.TRANSFER, {})


## 所有玩家关卡就绪（主机调用）。
func on_all_levels_ready() -> void:
	if _net == null or not _net.is_server():
		return
	if phase != RoomPhase.Phase.TRANSFER:
		return
	var levels: Array[String] = []
	for profile: PlayerProfile in _registry.all():
		if profile.is_spectator:
			continue
		if profile.level_ok and not profile.level_file_name.is_empty():
			levels.append(profile.level_file_name)
	if levels.is_empty():
		abort_to_lobby("没有可用的关卡，已返回大厅。")
		return
	levels.shuffle()
	Log.i("MPTEST] phase PLAY levels=%d" % levels.size())
	# 不要先赋给 random_levels 再放进 payload：_apply_play_phase 会 clear()，
	# 主机本地会把 payload 里的同一个数组一起清空（客户端因为走序列化反而没事）。
	s2c_phase_changed.rpc(
		RoomPhase.Phase.PLAY,
		{
			"levels": levels.duplicate(),
		}
	)


## 客户端上报单关结果；主机只做聚合，不推进阶段。
func report_level_result(level: String, passed: bool) -> void:
	if _net == null:
		return
	if _net.is_server():
		_apply_level_result(_net.local_id(), level, passed)
	else:
		c2s_level_result.rpc_id(1, level, passed)


## 客户端完成自己那一轮关卡后上报。
func notify_reach_end() -> void:
	if _net == null:
		return
	if _net.is_server():
		_apply_reach_end(_net.local_id())
	else:
		c2s_reach_end.rpc_id(1)


## 本地关卡索引变化时上报，用于重连后从正确的关卡继续。
func report_current_level(index: int) -> void:
	if _net == null:
		return
	if _net.is_server():
		_apply_current_level(_net.local_id(), index)
	else:
		c2s_report_level.rpc_id(1, index)


func request_return_to_lobby() -> void:
	if _net == null:
		return
	if _net.is_server():
		# 主机返回：整局结束，所有在结果页的人一起回标题。
		_return_to_lobby()
	else:
		# 客户端返回：只切自己，不能替其他人决定。
		Log.i("客户端返回标题（仅本地）")
		_switch_scene(SCENE_TITLE)


## 主机在出错时把整局拉回大厅。
func abort_to_lobby(reason: String) -> void:
	if _net == null or not _net.is_server():
		return
	if _host_edit_timer != null:
		_host_edit_timer.stop()
	Log.w("中止本局：%s" % reason)
	# 回大厅前清掉重连超时的记录，避免标题的玩家列表残留。
	_lobby.prune_abandoned()
	s2c_phase_changed.rpc(RoomPhase.Phase.LOBBY, {"reason": reason})


## 所有游玩玩家都已退出 / 掉线（宽限期已过）：整局没有继续的可能，
## 主机把所有人（含观战者）拉回标题，并提示“游玩玩家已全部掉线”。
func abort_all_playing_gone() -> void:
	if _net == null or not _net.is_server():
		return
	if not RoomPhase.is_in_game(phase):
		return
	if _host_edit_timer != null:
		_host_edit_timer.stop()
	Log.w("所有游玩玩家都已离开，整局返回标题")
	_lobby.reset_roster_for_lobby()
	random_levels.clear()
	current_level_count = 0
	s2c_phase_changed.rpc(
		RoomPhase.Phase.LOBBY,
		{
			"reason": "游玩玩家已全部掉线",
			"reason_title": "连接断开",
			"reason_ok": "返回标题画面",
		}
	)


func on_player_left(_id: int) -> void:
	if _net == null or not _net.is_server():
		return
	if phase == RoomPhase.Phase.RESULT:
		_check_all_reached_end()
	elif phase == RoomPhase.Phase.TRANSFER:
		# 传输阶段由 LevelTransferService 负责
		pass


func _apply_level_result(player_id: int, level: String, passed: bool) -> void:
	var author: PlayerProfile = null
	for profile: PlayerProfile in _registry.all():
		if profile.level_file_name == level:
			author = profile
			break
	if author != null:
		if passed:
			author.cause_pass += 1
		else:
			author.cause_death += 1
	for profile: PlayerProfile in _registry.all():
		if profile.id != player_id:
			continue
		if passed:
			profile.pass_count += 1
		Log.i(
			"玩家 %s %s %s 的关卡。"
			% [
				_manager.format_player(profile.name, profile.id),
				"通过" if passed else "死亡于",
				"?" if author == null else author.name,
			]
		)
		break


func _apply_reach_end(player_id: int) -> void:
	var profile: PlayerProfile = _registry.get_player(player_id)
	if profile == null:
		return
	if not profile.reach_end:
		profile.reach_end = true
		profile.is_in_result = true
		Log.i("玩家 %s 已经玩过了所有关卡！" % _manager.format_player(profile.name, profile.id))
		# 让其他客户端的观战目标列表知道他已经打完。
		_lobby.broadcast_delta(profile)
	_check_all_reached_end()


func _apply_current_level(player_id: int, index: int) -> void:
	var profile: PlayerProfile = _registry.get_player(player_id)
	if profile == null:
		return
	profile.current_level = maxi(0, index)
	# 只在换关时发，频率很低；观战者靠它知道目标在第几关。
	_lobby.broadcast_delta(profile)


func _check_all_reached_end() -> void:
	if _net == null or not _net.is_server():
		return
	if phase != RoomPhase.Phase.PLAY and phase != RoomPhase.Phase.RESULT:
		return
	for profile: PlayerProfile in _registry.all():
		if profile.is_spectator:
			continue
		if profile.abandoned:
			continue
		if not profile.reach_end:
			return
	_finish_match()


func _finish_match() -> void:
	if _net == null or not _net.is_server():
		return
	if phase == RoomPhase.Phase.RESULT:
		return
	Log.i("所有玩家已到达终点，计算结果中……")
	_write_level_results_to_files()
	var results: Array = []
	for profile: PlayerProfile in _registry.all():
		if profile.is_spectator:
			continue
		var total: int = profile.cause_pass + profile.cause_death
		var clear_rate: float = 0.0
		if total > 0:
			clear_rate = float(profile.cause_pass) / float(total)
		profile.clear_rate = clear_rate
		profile.score = _score_for(profile, clear_rate)
		results.append(profile.to_result_dict())
	Log.i("MPTEST] phase RESULT count=%d" % results.size())
	s2c_phase_changed.rpc(RoomPhase.Phase.RESULT, {"results": results})


func _score_for(profile: PlayerProfile, clear_rate: float) -> int:
	const A: float = 0.7
	const K: float = 5.0
	var score_clear_rate: float = 100.0 \
		* pow(clear_rate / A, K * A) \
		* pow((1.0 - clear_rate) / (1.0 - A), K * (1.0 - A))
	var total_players: int = maxi(1, _lobby.playing_count())
	var score_level_pass: float = 100.0 * float(profile.pass_count) / float(total_players)
	return int(round(score_clear_rate * 0.6 + score_level_pass * 0.4))


func _write_level_results_to_files() -> void:
	for profile: PlayerProfile in _registry.all():
		var path: String = profile.level_file_name
		if path.is_empty():
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			Log.e("结算时无法打开关卡文件：%s" % path)
			continue
		var content: String = file.get_as_text()
		file.close()
		var json: JSON = JSON.new()
		if json.parse(content) != OK:
			Log.e("结算时关卡 JSON 解析失败：%s" % path)
			continue
		var data: Dictionary = json.data
		data["pass_count"] = profile.cause_pass
		data["death_count"] = profile.cause_death
		var tmp_path: String = path + ".tmp"
		var output: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
		if output == null:
			Log.e("结算时无法写入关卡文件：%s" % path)
			continue
		output.store_string(JSON.stringify(data, ""))
		output.close()
		var dir: DirAccess = DirAccess.open("user://")
		if dir == null:
			continue
		if FileAccess.file_exists(path):
			dir.remove(path)
		var error: int = dir.rename(tmp_path, path)
		if error != OK:
			Log.e("结算时替换关卡文件失败：%s" % path)


func _return_to_lobby() -> void:
	if _net == null or not _net.is_server():
		return
	if phase == RoomPhase.Phase.LOBBY:
		return
	if _host_edit_timer != null:
		_host_edit_timer.stop()
	_lobby.reset_roster_for_lobby()
	random_levels.clear()
	current_level_count = 0
	Log.i("MPTEST] phase LOBBY")
	s2c_phase_changed.rpc(RoomPhase.Phase.LOBBY, {})


func _make_match_stamp() -> String:
	var stamp: String = Time.get_datetime_string_from_system(false, true)
	return stamp.replace(":", "-").replace(" ", "_")


@rpc("authority", "call_local", "reliable")
func s2c_phase_changed(new_phase: int, payload: Dictionary) -> void:
	_apply_phase(new_phase, payload)


func _apply_phase(new_phase: int, payload: Dictionary) -> void:
	var previous: int = phase
	if previous == new_phase and new_phase != RoomPhase.Phase.NONE:
		return
	phase = new_phase

	match new_phase:
		RoomPhase.Phase.EDIT:
			_apply_edit_phase(payload)
		RoomPhase.Phase.TRANSFER:
			_apply_transfer_phase()
		RoomPhase.Phase.PLAY:
			_apply_play_phase(payload)
		RoomPhase.Phase.RESULT:
			_apply_result_phase(payload)
		RoomPhase.Phase.LOBBY:
			_apply_lobby_phase(payload)

	phase_changed.emit(phase, payload)


func _apply_edit_phase(payload: Dictionary) -> void:
	edit_seconds = int(payload.get("edit_seconds", 0))
	var stamp: String = str(payload.get("stamp", ""))
	if not stamp.is_empty():
		_manager.game_start_time = stamp
	var mode: GameMode = GameModeSingleton
	mode.game_mode = GameMode.GameModeType.EDIT
	if edit_seconds > 0:
		var timer: Timer = TimerSingleton
		timer.wait_time = float(edit_seconds)
	_switch_scene(SCENE_SPECTATE if _is_local_spectator() else SCENE_READY)


func _apply_transfer_phase() -> void:
	var mode: GameMode = GameModeSingleton
	mode.game_mode = GameMode.GameModeType.EDIT
	# 切场景前让编辑房间把自己的关卡落盘，传输服务随后直接读文件。
	_manager.save_level_requested.emit()
	_switch_scene(SCENE_SPECTATE if _is_local_spectator() else SCENE_TRANSFER)
	if _net.is_server():
		_manager.levels.begin_collect()
	else:
		_manager.levels.submit_local_level.call_deferred()


func _apply_play_phase(payload: Dictionary) -> void:
	var mode: GameMode = GameModeSingleton
	mode.game_mode = GameMode.GameModeType.PLAY
	random_levels.clear()
	var levels: Array = payload.get("levels", [])
	for entry: Variant in levels:
		random_levels.append(str(entry))
	current_level_count = int(payload.get("current_level", 0))
	_switch_scene(SCENE_SPECTATE if _is_local_spectator() else SCENE_PLAY)


func _apply_result_phase(payload: Dictionary) -> void:
	var mode: GameMode = GameModeSingleton
	mode.game_mode = GameMode.GameModeType.PLAY
	var results: Array = payload.get("results", [])
	last_results = results
	result_updated.emit(results)
	# 结算阶段所有人（含观战者）都看结果页。
	_switch_scene(SCENE_RESULT)


func _apply_lobby_phase(payload: Dictionary) -> void:
	var mode: GameMode = GameModeSingleton
	mode.game_mode = GameMode.GameModeType.EDIT
	random_levels.clear()
	current_level_count = 0
	var reason: String = str(payload.get("reason", ""))
	if not reason.is_empty():
		# 标题与按钮文案可随载荷覆盖（例如“游玩玩家已全部掉线”/“返回标题画面”）。
		Notice.show_notice(
			reason,
			str(payload.get("reason_title", "返回大厅")),
			str(payload.get("reason_ok", "确认"))
		)
	_switch_scene(SCENE_TITLE)


## 新加入的观战者 / 重连玩家：补发当前阶段与阶段载荷。
func s2c_sync_phase_to(peer_id: int) -> void:
	if _net == null or not _net.is_server():
		return
	var payload: Dictionary = {}
	match phase:
		RoomPhase.Phase.EDIT:
			payload = {
				"edit_seconds": edit_seconds,
				"stamp": _manager.game_start_time,
			}
		RoomPhase.Phase.PLAY:
			var profile: PlayerProfile = _registry.get_player(peer_id)
			payload = {
				"levels": random_levels.duplicate(),
				"current_level": 0 if profile == null else profile.current_level,
			}
		RoomPhase.Phase.RESULT:
			payload = {"results": last_results.duplicate(true)}
	s2c_phase_changed.rpc_id(peer_id, phase, payload)


func _is_local_spectator() -> bool:
	var local: PlayerProfile = _manager.get_local_player()
	return local != null and local.is_spectator


func _switch_scene(uid: String) -> void:
	var target_path: String = ""
	if uid.begins_with("res://"):
		target_path = uid
	else:
		var target_id: int = ResourceUID.text_to_id(uid)
		if target_id == ResourceUID.INVALID_ID:
			Log.e("无效场景 UID：%s" % uid)
			return
		target_path = ResourceUID.get_id_path(target_id)
	var current: Node = get_tree().current_scene
	if current != null and current.scene_file_path == target_path:
		return
	GlobalTransition.change_scene_to_file(uid)


# ---------------------------------------------------------------------------
# 客户端 -> 主机
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func c2s_level_result(level: String, passed: bool) -> void:
	if _net == null or not _net.is_server():
		return
	if phase != RoomPhase.Phase.PLAY:
		return
	_apply_level_result(multiplayer.get_remote_sender_id(), level, passed)


@rpc("any_peer", "call_remote", "reliable")
func c2s_reach_end() -> void:
	if _net == null or not _net.is_server():
		return
	_apply_reach_end(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c2s_report_level(index: int) -> void:
	if _net == null or not _net.is_server():
		return
	if phase != RoomPhase.Phase.PLAY:
		return
	_apply_current_level(multiplayer.get_remote_sender_id(), index)


