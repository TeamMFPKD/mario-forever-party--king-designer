extends Node

class_name MultiplayerManager

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 多人联机门面（autoload 名仍是 MPManager）。
##
## 只做三件事：
## 1. 持有各服务节点并转发信号；
## 2. 对外提供少量公开 API（host_game / join_game / leave_room）；
## 3. 给尚未完全迁移的 UI 提供只读兼容属性（players / messages / is_in_game 等）。
##
## 传输、玩家资料、关卡分发、阶段推进、聊天分别在：
## NetPeer / SessionRegistry / LobbyService / LevelTransferService /
## MatchFlowService / ChatService。

const PORT_MIN: int = 1
const PORT_MAX: int = 65535
const JOIN_SOUND: AudioStream = preload("res://sound/SE_NetworkOK.wav")
const EXIT_SOUND: AudioStream = preload("res://sound/SE_NetworkLeft.wav")
const PORT_INVALID_MESSAGE: String = "端口需为 %d~%d 之间的数字，请检查后重试。"
const CONNECT_FAILED_MESSAGE: String = "无法连接到 %s:%d。\n请确认地址与端口正确，且房主已经创建房间。"

signal players_updated
signal edit_all_ready
signal result_updated(results: Array)
signal messages_updated
signal phase_changed(phase: int, payload: Dictionary)
## 编辑阶段结束前请求各端把当前关卡落盘（关卡传输服务会立刻读取该文件）。
signal save_level_requested
signal play_sound_joined
signal play_sound_exited

enum LobbyPage {
	NONE,
	HOST,
	JOIN,
}

var net: NetPeer
var registry: SessionRegistry
var lobby: LobbyService
var levels: LevelTransferService
var flow: MatchFlowService
var chat: ChatService

var local_port: int = 8914
var remote_port: int = 0
var frp_domain: String = ""
var player_name: String = ""
var game_start_time: String = ""
var device_id: String = "invalid"

## 本地玩家资料。未进房时也存在，头像选择器可以直接写。
var player: PlayerProfile = PlayerProfile.new()

var _lobby_page: int = LobbyPage.NONE
## 上一次失败弹出的“加入失败”提示是否还开着；连上后要主动关掉，
## 否则它会盖住玩家列表（Notice 是全局模态面板）。
var _join_failure_notice_open: bool = false


func _ready() -> void:
	# autoload 必须是脚本（不能是 .tscn），否则 MPManager 的静态类型会退化成 Node。
	# 各服务在 _ready 里创建，节点路径固定为 /root/MPManager/<Service>，RPC 跨场景稳定。
	net = NetPeer.new()
	net.name = "NetPeer"
	add_child(net)

	registry = SessionRegistry.new()
	registry.name = "SessionRegistry"
	add_child(registry)

	lobby = LobbyService.new()
	lobby.name = "LobbyService"
	add_child(lobby)

	levels = LevelTransferService.new()
	levels.name = "LevelTransferService"
	add_child(levels)

	flow = MatchFlowService.new()
	flow.name = "MatchFlowService"
	add_child(flow)

	chat = ChatService.new()
	chat.name = "ChatService"
	add_child(chat)

	device_id = get_device_tag()
	player.device_id = device_id

	lobby.setup(self, registry, net)
	levels.setup(self, registry, net, lobby)
	flow.setup(self, registry, net, lobby)
	chat.setup(self)

	registry.player_added.connect(_on_player_added)
	registry.player_removed.connect(_on_player_removed)
	registry.player_changed.connect(_on_player_changed)
	registry.registry_reset.connect(_on_registry_reset)

	net.joined.connect(_on_joined)
	net.connect_failed.connect(_on_connect_failed)
	net.server_lost.connect(_on_server_lost)
	net.room_closed.connect(_on_room_closed)

	lobby.join_rejected.connect(_on_join_rejected)
	lobby.all_edit_finished.connect(_on_all_edit_finished)
	levels.all_levels_ready.connect(_on_all_levels_ready)
	flow.phase_changed.connect(_on_phase_changed)
	flow.result_updated.connect(_on_result_updated)
	chat.messages_updated.connect(_on_messages_updated)


# ---------------------------------------------------------------------------
# 只读兼容属性
# ---------------------------------------------------------------------------

var players: Array[PlayerProfile]:
	get:
		if registry == null:
			return []
		return registry.all()

var messages: Array:
	get:
		if chat == null:
			return []
		return chat.messages

var phase: int:
	get:
		if flow == null:
			return RoomPhase.Phase.NONE
		return flow.phase

var is_in_game: bool:
	get:
		return RoomPhase.is_in_game(phase)

var random_levels: Array[String]:
	get:
		if flow == null:
			return []
		return flow.random_levels

var current_level_count: int:
	get:
		if flow == null:
			return 0
		return flow.current_level_count
	set(value):
		if flow != null:
			flow.current_level_count = value

var total_levels: int:
	get:
		return random_levels.size()


# ---------------------------------------------------------------------------
# 公开 API
# ---------------------------------------------------------------------------

func host_game(port: int) -> void:
	if net.is_online() or net.is_connecting():
		Log.i("已在房间或正在连接，忽略重复的开房请求")
		return
	_lobby_page = LobbyPage.HOST
	if not net.is_valid_port(port):
		Log.w("创建房间失败：本地端口无效（%d）" % port)
		Notice.show_notice(PORT_INVALID_MESSAGE, "创建房间失败", "确认", [PORT_MIN, PORT_MAX])
		return

	var error: int = net.host(port)
	if error != OK:
		Log.e("创建服务器失败（本地端口 %d）：%s" % [port, error_string(error)])
		Notice.show_notice(
			"端口 %d 已被占用，房间未能创建。\n请关闭占用该端口的程序，或更换端口后重试。",
			"创建房间失败",
			"确认",
			[port]
		)
		return

	player.id = net.local_id()
	player.name = player_name.substr(0, PlayerProfile.NAME_LIMIT)
	player.device_id = device_id
	player.is_host = true
	player.lobby_ready = false
	player.reset_match_state()
	registry.clear()
	registry.add(player)
	flow.phase = RoomPhase.Phase.LOBBY
	Log.i("主机已启动。")
	Log.i("主机玩家：%s" % [format_player(player.name, player.id)])


func join_game(address: String, port: int) -> void:
	if net.is_online() or net.is_connecting():
		# 重复点“加入”时 net.join() 会返回 ERR_ALREADY_IN_USE；
		# 那不是连接失败，静默忽略，避免已经进房还弹“加入失败”。
		Log.i("已在房间或正在连接，忽略重复的加入请求")
		return
	_lobby_page = LobbyPage.JOIN
	var domain: String = address.strip_edges()
	if domain.is_empty():
		Log.w("加入房间失败：未填写组织方 IP / 域名")
		_join_failure_notice_open = true
		Notice.show_notice("请填写组织方 IP 或域名。", "加入房间失败")
		return
	if not net.is_valid_port(port):
		Log.w("加入房间失败：远程端口无效（%d）" % port)
		_join_failure_notice_open = true
		Notice.show_notice(PORT_INVALID_MESSAGE, "加入房间失败", "确认", [PORT_MIN, PORT_MAX])
		return

	Log.i(["连接IP：", domain])
	Log.i(["连接端口：", port])
	var error: int = net.join(domain, port)
	if error != OK:
		Log.e("加入房间失败（%s:%d）：%s" % [domain, port, error_string(error)])
		_join_failure_notice_open = true
		Notice.show_notice(CONNECT_FAILED_MESSAGE, "加入房间失败", "确认", [domain, port])
		return
	Log.i(["正在连接到服务器: ", domain])


func leave_room(reason: String = "主动退出") -> void:
	if net == null or not net.is_online():
		_cleanup_session()
		return
	if net.is_server():
		Log.i("玩家 %s — %s" % [format_player(player.name, player.id), reason])
		net.close_room()
		return
	net.c2s_leave_reason.rpc_id(1, reason)
	for _index: int in range(2):
		await get_tree().physics_frame
	net.leave()
	_cleanup_session()


## 兼容旧调用点。
func disconnect_and_cleanup(reason: String = "主动退出") -> void:
	await leave_room(reason)


func get_local_player() -> PlayerProfile:
	if net == null or not net.is_online():
		return player
	var profile: PlayerProfile = registry.get_player(net.local_id())
	if profile != null:
		return profile
	return player


func get_lobby_page() -> int:
	return _lobby_page


## 玩家身份色（头像外圈 / 消息气泡描边）。
##
## 只看玩家在房间名单里的位置，各端算出来一致，所以不走网络同步。
## 不在名单里（还没进房、或消息发送者已经离开）时按 1P 的白色处理。
func player_color(player_id: int) -> Color:
	if registry != null:
		var index: int = registry.ids().find(player_id)
		if index >= 0:
			return PlayerColor.for_index(index)
	return PlayerColor.for_index(0)


func is_server() -> bool:
	return net != null and net.is_server()


func restore_origin_player_data() -> void:
	if registry != null:
		registry.reset_match_state()


# ---------------------------------------------------------------------------
# 信号转发 / 本地状态
# ---------------------------------------------------------------------------

func _on_joined() -> void:
	Log.i("连接成功")
	_dismiss_join_failure_notice()
	player.id = net.local_id()
	player.name = player_name.substr(0, PlayerProfile.NAME_LIMIT)
	player.device_id = device_id
	if flow.phase == RoomPhase.Phase.NONE:
		flow.phase = RoomPhase.Phase.LOBBY
	lobby.send_join_request()
	_confirm_roster_after_join()


## 加入请求发出后补拉一次名单：初始快照万一没到，也不会让列表永远空着。
func _confirm_roster_after_join() -> void:
	await get_tree().create_timer(0.5).timeout
	if net.is_online():
		lobby.request_roster()


func _on_connect_failed(reason: String) -> void:
	Log.e("连接服务器失败：%s" % reason)
	if _lobby_page == LobbyPage.JOIN:
		_join_failure_notice_open = true
		Notice.show_notice(
			CONNECT_FAILED_MESSAGE,
			"加入房间失败",
			"确认",
			[frp_domain.strip_edges(), remote_port]
		)
	if registry != null:
		registry.clear()
	if flow != null:
		flow.phase = RoomPhase.Phase.NONE


func _on_server_lost() -> void:
	Log.w("与主机断开")
	var was_in_game: bool = is_in_game
	_cleanup_session()
	Notice.show_notice("与主机断开。", "连接断开")
	if was_in_game:
		GlobalTransition.change_scene_to_file(flow.SCENE_TITLE)


func _on_room_closed() -> void:
	Log.i("服务器即将关闭")
	var was_in_game: bool = is_in_game
	_cleanup_session()
	if was_in_game:
		GlobalTransition.change_scene_to_file(flow.SCENE_TITLE)


func _on_join_rejected(reason: String) -> void:
	_join_failure_notice_open = false
	Notice.show_notice(reason, "无法加入房间")
	_cleanup_session()
	net.leave()


func _dismiss_join_failure_notice() -> void:
	if not _join_failure_notice_open:
		return
	_join_failure_notice_open = false
	if Notice.is_notice_visible():
		Notice.hide_notice()


func _on_player_added(_id: int) -> void:
	emit_signal("players_updated")
	if registry.size() > 1:
		play_sound_joined.emit()
		_play_join_sound()


func _on_player_removed(_id: int, _display_name: String) -> void:
	emit_signal("players_updated")
	play_sound_exited.emit()
	_play_exit_sound()


func _play_join_sound() -> void:
	_play_ui_sound(JOIN_SOUND)


func _play_exit_sound() -> void:
	_play_ui_sound(EXIT_SOUND)


func _play_ui_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Sound"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _on_player_changed(_id: int, _group: StringName) -> void:
	emit_signal("players_updated")


func _on_registry_reset() -> void:
	on_roster_replaced()


func _on_all_edit_finished() -> void:
	edit_all_ready.emit()
	if net.is_server():
		flow.finish_edit("所有玩家已准备完毕，提前结束倒计时")


func _on_all_levels_ready() -> void:
	flow.on_all_levels_ready()


func _on_result_updated(results: Array) -> void:
	result_updated.emit(results)


func _on_phase_changed(new_phase: int, payload: Dictionary) -> void:
	phase_changed.emit(new_phase, payload)


func _on_messages_updated() -> void:
	emit_signal("messages_updated")


## 客户端收到主机快照后，本地 player 引用要指向新对象。
func on_roster_replaced() -> void:
	# 收到名单说明加入已经成功，上一轮失败提示不该再挡着玩家列表。
	_dismiss_join_failure_notice()
	if net != null and net.is_online():
		var profile: PlayerProfile = registry.get_player(net.local_id())
		if profile != null:
			player = profile
	# 无论主机还是客户端都要通知 UI；客户端之前就是漏了这一句，
	# 快照收到了但玩家列表永远不刷新。
	emit_signal("players_updated")


func _cleanup_session() -> void:
	if registry != null:
		registry.clear()
	if chat != null:
		chat.clear()
	var keep_name: String = player.name
	var keep_avatar: String = player.avatar_id
	player = PlayerProfile.new()
	player.name = keep_name
	player.avatar_id = keep_avatar
	player.device_id = device_id
	if flow != null:
		flow.phase = RoomPhase.Phase.NONE
		flow.random_levels.clear()
		flow.current_level_count = 0


# ---------------------------------------------------------------------------
# 日志辅助
# ---------------------------------------------------------------------------

func _get_tag(player_device_id: String) -> String:
	if player_device_id.is_empty():
		return "?????"
	return player_device_id.substr(0, 5)


func get_device_tag() -> String:
	var unique_id: String = OS.get_unique_id()
	if unique_id.is_empty():
		return "?????"
	unique_id = unique_id.replace("{", "").replace("}", "").replace("-", "")
	return unique_id.substr(0, 5)


func format_player(p_name: Variant, p_id: Variant) -> String:
	return "[%s] %s (%s)" % [get_player_device_tag(p_id), p_name, p_id]


func get_player_device_tag(player_id: Variant) -> String:
	if registry != null:
		for profile: PlayerProfile in registry.all():
			if profile.id == int(player_id):
				return profile.device_tag()
	if player != null and player.id == int(player_id):
		return player.device_tag()
	return "?????"


func print_players() -> void:
	for profile: PlayerProfile in players:
		Log.i(" %s" % [format_player(profile.name, profile.id)])
		Log.i(
			"   ready=%s  edit=%s  level_ok=%s  file=%s"
			% [profile.lobby_ready, profile.edit_finished, profile.level_ok, profile.level_file_name]
		)
