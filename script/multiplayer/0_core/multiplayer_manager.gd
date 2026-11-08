extends Node

class_name MultiplayerManager

const MpAniSpriteManagerScript: GDScript = preload("res://script/multiplayer/5_play/multiplayer_ani_sprite_manager.gd")

## 端口合法范围（ENet 只接受 1~65535）
const PORT_MIN: int = 1
const PORT_MAX: int = 65535

## msgid：端口填错（开房与进房共用）
const PORT_INVALID_MESSAGE: String = "端口需为 %d~%d 之间的数字，请检查后重试。"
## msgid：连不上主机（create_client 失败、连接超时共用）
const CONNECT_FAILED_MESSAGE: String = "无法连接到 %s:%d。\n请确认地址与端口正确，且房主已经创建房间。"

## 连接主机的超时（毫秒）。ENet 自己要 30 秒以上才判定失败，玩家会以为“点了没反应”。
const JOIN_TIMEOUT_MSEC: int = 10000

signal players_updated

signal timeout_save

## 所有玩家都完成关卡编辑（编辑房间按下“准备完毕”），可提前结束倒计时
signal edit_all_ready

signal result_updated

signal play_sound_joined
signal play_sound_exited

signal messages_updated

@export var player_dead_spritesframe: SpriteFrames

var local_port: int
# 端口使用Sakura Frp隧道配置的远程端口
var remote_port: int
# Sakura Frp提供的域名
var frp_domain: String = ""
var player_name: String = ""

var game_start_time: String

var messages: Array = []
var msg_cnt: int = 0

# 玩家列表，仅由主机(host)保持权威，直到传输关卡数据之前
var players: Array = []:
	set(value):
		#print("[%s] players set player size: " % Time.get_time_string_from_system(), players.size())
		#for p in players:
			#print("[%s] players set player: %s" % [Time.get_time_string_from_system(), format_player(p.name, p.id)])
		#print("[%s] players set value size: " % Time.get_time_string_from_system(), value.size())
		#for v in value:
			#print("[%s] players set value player: %s" % [Time.get_time_string_from_system(), format_player(v.name, v.id)])
		if players.size() < value.size():
			emit_signal("play_sound_joined")
			#print("[%s] play sound joined" % Time.get_time_string_from_system())
		if players.size() > value.size():
			emit_signal("play_sound_exited")
			#print("[%s] play sound exited" % Time.get_time_string_from_system())
		players = value

		if value.size() < 2 and multiplayer.is_server():
			msg_cnt = 0

var random_levels: Array = []
var current_level_count: int = 0

var total_levels: int = 0

var level_results: Array = []

var _pending_disconnect_reasons: Dictionary = {}

## 标题界面里最近一次尝试的开房 / 进房方式：失败或掉线后据此退回对应的设置页
enum LobbyPage {
	NONE,
	HOST,
	JOIN,
}
var _lobby_page: LobbyPage = LobbyPage.NONE

## 主动退出 / 房主主动关房时，短暂屏蔽“与主机断开”提示
var _suppress_disconnect_notice: bool = false

## 本次等待进房的截止时间（0 表示没有正在等待的连接）
var _join_deadline_msec: int = 0

var is_in_game: bool = false:
	set(value):
		is_in_game = value
		random_levels.clear()
		current_level_count = 0
		total_levels = 0
		level_results.clear()
		for p: Dictionary in players:
			p.is_ready_to_finish = false
		var game_mode_singleton: GameMode = GameModeSingleton
		game_mode_singleton.game_mode = GameMode.GameModeType.EDIT

@export var player_small_spritesframe: SpriteFrames
@export var player_super_spritesframe: SpriteFrames
@export var player_fireball_spritesframe: SpriteFrames
@export var player_beetroot_spritesframe: SpriteFrames
@export var player_lui_spritesframe: SpriteFrames
@export var player_big_spritesframe: SpriteFrames
@export var player_bee_spritesframe: SpriteFrames
@export var player_cloud_spritesframe: SpriteFrames

var mp_ani_manager: MpAniSpriteManagerScript

# 自己的玩家信息
var player: Dictionary = {
	"id": "invalid",
	"name": "invalid",
	"is_ready_to_start": false,
	"is_ready_to_finish": false,
	"level_file_name": "invalid",
	"level_data": "invalid",
	"ready": false,
	"reach_end": false,
	"level_cause_pass": 0,
	"level_cause_death": 0,
	"level_pass_count": 0,
	"clear_rate": 0.0,
	"score": 0,
	"device_id": "invalid",
}
var device_id: String = "invalid"


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	device_id = get_device_tag()

func _on_host_button_pressed() -> void:
	_lobby_page = LobbyPage.HOST
	# 换去开房时，把还没到期的进房超时作废
	_join_deadline_msec = 0

	# 端口填错时不必去调 ENet——它要么拒绝，要么真的绑一个别的端口，两种都让人一头雾水
	if not _is_valid_port(local_port):
		Log.w("创建房间失败：本地端口无效（%d）" % local_port)
		_restore_lobby_page()
		Notice.show_notice(PORT_INVALID_MESSAGE, "创建房间失败", "确认", [PORT_MIN, PORT_MAX])
		return

	# 主机端代码通常不需要修改，仍监听本地端口
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# 注意：这里监听的端口是本地端口，需要与FRP隧道配置的"本地端口"一致
	var error: int = peer.create_server(local_port, 20)
	if error != OK:
		# 端口被占用（常见于上一次测试的 host 进程没退干净）时绝不能继续设置
		# multiplayer_peer，否则主机会停留在“看似已开服、实际没人连得上”的假状态。
		Log.e("创建服务器失败（本地端口 %d）：%s" % [local_port, error_string(error)])
		_restore_lobby_page()
		Notice.show_notice(
			"端口 %d 已被占用，房间未能创建。\n请关闭占用该端口的程序，或更换端口后重试。",
			"创建房间失败",
			"确认",
			[local_port],
		)
		return

	multiplayer.multiplayer_peer = peer

	player.id = multiplayer.get_unique_id()
	player.name = player_name
	player.device_id = device_id

	players.append(player)
	emit_signal("players_updated")
	_show_player_page()
	Log.i("主机已启动。")
	Log.i("主机玩家：%s" % [format_player(player_name, player.id)])

func _is_valid_port(port: int) -> bool:
	return port >= PORT_MIN and port <= PORT_MAX

## 失败 / 掉线后回到最近一次使用的开房页或进房页，让玩家能直接改参数重试。
## 标题界面不在场（已经进游戏）时什么也不做。
func _restore_lobby_page() -> void:
	var title: Node = get_node_or_null("/root/Title")
	if title == null:
		return
	var player_page: Control = title.get_node_or_null("GameRoomSize/PlayerPage") as Control
	if player_page:
		player_page.visible = false
	var host_page: Control = title.get_node_or_null("GameRoomSize/HostPage") as Control
	if host_page:
		host_page.visible = _lobby_page == LobbyPage.HOST
	var join_page: Control = title.get_node_or_null("GameRoomSize/JoinPage") as Control
	if join_page:
		join_page.visible = _lobby_page == LobbyPage.JOIN

## 开房 / 进房成功后切到玩家列表页。
## 正常走按钮时按钮自己会切，MpTestBoot 之类直接调本类的路径也要保证界面一致。
func _show_player_page() -> void:
	var title: Node = get_node_or_null("/root/Title")
	if title == null:
		return
	var host_page: Control = title.get_node_or_null("GameRoomSize/HostPage") as Control
	if host_page:
		host_page.visible = false
	var join_page: Control = title.get_node_or_null("GameRoomSize/JoinPage") as Control
	if join_page:
		join_page.visible = false
	var player_page: Control = title.get_node_or_null("GameRoomSize/PlayerPage") as Control
	if player_page:
		player_page.visible = true

## 主动退出 / 房主主动关房时，0.5 秒内不把随之而来的 server_disconnected 当成错误。
func _hold_disconnect_notice() -> void:
	_suppress_disconnect_notice = true
	await get_tree().create_timer(0.5).timeout
	_suppress_disconnect_notice = false

func _on_join_button_pressed() -> void:
	_lobby_page = LobbyPage.JOIN

	var domain: String = frp_domain.strip_edges()
	if domain.is_empty():
		Log.w("加入房间失败：未填写组织方 IP / 域名")
		_restore_lobby_page()
		Notice.show_notice("请填写组织方 IP 或域名。", "加入房间失败")
		return
	if not _is_valid_port(remote_port):
		Log.w("加入房间失败：远程端口无效（%d）" % remote_port)
		_restore_lobby_page()
		Notice.show_notice(PORT_INVALID_MESSAGE, "加入房间失败", "确认", [PORT_MIN, PORT_MAX])
		return

	Log.i(["连接IP：", domain])
	Log.i(["连接端口：", remote_port])
	Log.i("本地玩家：%s" % [format_player(player_name, multiplayer.get_unique_id())])

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(domain, remote_port)
	if error != OK:
		# 地址 / 端口本身就不合法（例如带空格、端口越界），ENet 会直接拒绝
		Log.e("加入房间失败（%s:%d）：%s" % [domain, remote_port, error_string(error)])
		_restore_lobby_page()
		Notice.show_notice(CONNECT_FAILED_MESSAGE, "加入房间失败", "确认", [domain, remote_port])
		return

	multiplayer.multiplayer_peer = peer
	_join_deadline_msec = Time.get_ticks_msec() + JOIN_TIMEOUT_MSEC
	Log.i(["正在连接到服务器: ", domain])

## 自己盯一个比 ENet 更短的进房超时，超时后主动断开并提示。
func _process(_delta: float) -> void:
	if _join_deadline_msec == 0:
		return
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING:
		_join_deadline_msec = 0
		return
	if Time.get_ticks_msec() < _join_deadline_msec:
		return
	_join_deadline_msec = 0
	Log.w("连接主机超时（%d 毫秒），主动放弃本次连接" % JOIN_TIMEOUT_MSEC)
	# 置空比 close() 干净：连接状态确定回到“未连接”，玩家再点一次就是全新尝试
	multiplayer.multiplayer_peer = null
	_notify_join_failed()

func _on_connected_to_server() -> void:
	Log.i("连接成功")
	_join_deadline_msec = 0
	# 客户端连接成功后，向主机发送自己的玩家信息
	player.id = multiplayer.get_unique_id()
	player.name = player_name
	player.device_id = device_id
	# 仅向主机发送加入请求
	register_player_on_host.rpc_id(1, player)
	_show_player_page()

## 客户端连接失败（主机没开、地址不通、超时被拒）。
func _on_connection_failed() -> void:
	_join_deadline_msec = 0
	Log.e("连接服务器失败：%s:%d" % [frp_domain, remote_port])
	_notify_join_failed()

## 进房失败的统一提示：退回进房页，告诉玩家可能的原因。
func _notify_join_failed() -> void:
	if _lobby_page != LobbyPage.JOIN:
		return
	_restore_lobby_page()
	Notice.show_notice(
		CONNECT_FAILED_MESSAGE,
		"加入房间失败",
		"确认",
		[frp_domain.strip_edges(), remote_port],
	)

## 客户端与主机断开（房主关房、房主崩溃、网络中断）。
func _on_server_disconnected() -> void:
	if _suppress_disconnect_notice:
		Log.i("与主机断开（主动退出，不提示）")
		return
	Log.w("与主机断开")
	if not is_in_game:
		# 还在标题的房间里：清空房间数据，并退回进房页方便重试
		restore_origin_player_data()
		players.clear()
		messages.clear()
		emit_signal("players_updated")
		emit_signal("messages_updated")
		_lobby_page = LobbyPage.JOIN
		_restore_lobby_page()
	Notice.show_notice("与主机断开。", "连接断开")

@rpc("any_peer", "call_remote")
func register_player_on_host(player_info: Dictionary) -> void:
	# 只有主机执行此函数
	if not multiplayer.is_server():
		return
	
	if is_in_game:
		push_warning(player_info.id, player_info.name, "试图加入游戏，但是游戏开始了——")
		var player_info_id: int = player_info["id"]
		inform_late_player.rpc_id(player_info_id)
		return

	# 更新主机本地的玩家列表
	# 这样写是为了触发 players 的 set 方法，因为 Array.append() 不会触发 set 方法
	var p_list: Array = players.duplicate()
	p_list.append(player_info)
	
	# 通知所有对等体有新玩家加入
	player_joined.rpc(player_info)
	
	# 同步完整的玩家列表给所有客户端
	sync_players_list.rpc(p_list)

	# 同步所有聊天记录给新客户端
	sync_messages.rpc(messages)

@rpc("authority", "call_remote")
func inform_late_player() -> void:
	Log.w("已连接主机。但该房间游戏已经开始。即将断开连接。")
	Notice.show_notice("游戏已经开始，无法加入该房间。", "游戏进行中")
	disconnect_and_cleanup("游戏已开始，拒绝加入")

@rpc("authority", "call_local")
func player_joined(player_info: Dictionary) -> void:
	var device_tag_id: String = player_info.get("device_id", "")
	var tag: String = _get_tag(device_tag_id)
	Log.i("玩家 [%s] %s (%s) 已加入" % [tag, player_info.name, player_info.id])

@rpc("authority", "call_local")
func sync_players_list(players_list: Array) -> void:
	# 所有客户端接收并更新玩家列表
	players = players_list
	emit_signal("players_updated")
	print_players()

func _on_peer_connected(_id: int) -> void:
	# 当有新对等体连接时，如果是主机，不需要额外处理
	# 因为 register_player_on_host 已经处理了逻辑
	pass

func _on_peer_disconnected(id: int) -> void:
	# 当对等体断开连接时
	if multiplayer.is_server():
		var p_name: String = "?"
		var p_device_id: String = ""
		for p: Dictionary in players:
			if p.id == id:
				p_name = str(p.name)
				p_device_id = str(p.get("device_id", ""))
				break
		
		# 服务器：从 players 列表中移除离开的玩家
		# 这样写是为了触发 players 的 set 方法，因为 Array.append() 不会触发 set 方法
		var p_list: Array = players.duplicate()
		for i: int in range(p_list.size()):
			var p_item: Dictionary = p_list[i]
			if p_item.id == id:
				p_list.remove_at(i)
				players = p_list
				break
		
		emit_signal("players_updated")
		var reason: Variant = _pending_disconnect_reasons.get(id, "意外断开连接")
		_pending_disconnect_reasons.erase(id)
		var tag: String = _get_tag(p_device_id)
		Log.w("玩家 [%s] %s (%s) — %s" % [tag, p_name, id, reason])
		# 通知其他客户端更新玩家列表
		if players.size() > 0:
			sync_players_list.rpc(players)
		# 掉线的是唯一还没完成编辑的玩家时，剩余玩家可以立刻开始
		_check_all_edit_ready()

# 服务器通知所有客户端退出房间
@rpc("authority", "call_local")
func server_closing() -> void:
	Log.i("服务器即将关闭")
	# 客户端是被动退出房间，别把随之而来的 server_disconnected 当成错误弹出来
	if not multiplayer.is_server():
		_hold_disconnect_notice()
	# 隐藏 PlayerPage
	var player_page: Control = get_node_or_null("/root/Title/GameRoomSize/PlayerPage")
	if player_page:
		player_page.visible = false
	players = []
	emit_signal("players_updated")
	# 断开连接
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

@rpc("any_peer", "call_remote")
func notify_disconnect(reason: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_pending_disconnect_reasons[sender_id] = reason

# 断开连接并清理
func disconnect_and_cleanup(reason: String = "意外断开连接") -> void:
	_hold_disconnect_notice()
	var tag: String = format_player(player.name, player.id)
	if multiplayer.is_server():
		Log.i("玩家 %s — %s" % [tag, reason])
		server_closing.rpc()
	else:
		notify_disconnect.rpc_id(1, reason)
		for i: int in range(2):
			await get_tree().physics_frame
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	
	# Clear player
	restore_origin_player_data()
	# Clear players
	players.clear()
	# Clear messages
	messages.clear()
	emit_signal("players_updated")
	emit_signal("messages_updated")

@rpc("authority")
func edit_time_out() -> void:
	emit_signal("timeout_save")

@rpc("any_peer", "call_local")
func transfer_level_data(player_id: int, level_file_name: String, level_data_bytes_compressed: PackedByteArray) -> void:
	# 防止结束时主机发送不带关卡数据的玩家信息，导致空关卡数据覆盖本地文件
	if player.reach_end:
		return
	if level_file_name == "invalid" or level_file_name.is_empty():
		Log.e("transfer_level_data received invalid file name")
		return
	for p: Dictionary in players:
		if p.id == player_id:
			p.level_file_name = level_file_name
			
			# 1. 解压
			var level_data_bytes: PackedByteArray = level_data_bytes_compressed.decompress_dynamic(-1, FileAccess.CompressionMode.COMPRESSION_DEFLATE)
			if level_data_bytes.is_empty():
				Log.e("解压失败，压缩数据大小：%d 字节" % [level_data_bytes_compressed.size()])
				p.level_data = "invalid"
				return
			
			Log.i("解压成功，字节数：%d" % [level_data_bytes.size()])
			
			# 2. 转 UTF-8 字符串
			var level_json: String = level_data_bytes.get_string_from_utf8()
			if level_json.is_empty():
				Log.e("UTF-8 转换失败，字节数据可能不是有效文本")
				p.level_data = "invalid"
				return
			
			p.level_data = level_json
			emit_signal("players_updated")
			
			if p.id == player.id:
				Log.i("已将自己的关卡数据加入玩家列表数据")
			else:
				Log.i("已接收玩家 %s 的关卡数据，JSON 长度：%d" % [format_player(p.name, p.id), level_json.length()])
			break

@rpc("any_peer", "call_local")
func my_players_data_are_ready(player_id: int) -> void:
	for p: Dictionary in players:
		if p.id == player_id:
			p.ready = true
			Log.i("玩家 %s 已准备就绪" % [format_player(p.name, p.id)])
			break
	if multiplayer.is_server():
		# 只广播就绪状态，避免把体积庞大的关卡数据再同步一遍
		sync_player_ready.rpc(player_id)

@rpc("authority", "call_local")
func sync_player_ready(player_id: int) -> void:
	for p: Dictionary in players:
		if p.id == player_id:
			p.ready = true
			break
	emit_signal("players_updated")

@rpc("authority", "call_local")
func lets_play_together(rnd_levels: Array) -> void:
	self.random_levels = rnd_levels
	if multiplayer.is_server():
		level_results = []
		for level: Variant in rnd_levels:
			level_results.append({
				"level": level,
				"pass_count": 0,
				"death_count": 0,
			})
	current_level_count = 0
	total_levels = rnd_levels.size()
	var game_mode: GameMode = GameModeSingleton
	game_mode.game_mode = GameMode.GameModeType.PLAY
	GlobalTransition.change_scene_to_file("uid://cxvueju65b3qv")

@rpc("any_peer", "call_local")
func level_add_pass_count(level: Variant, passed: bool, player_id: int) -> void:
	if not multiplayer.is_server():
		return
	for p_author: Dictionary in players:
		if p_author["level_file_name"] != level:
			continue
		if passed:
			p_author["level_cause_pass"] += 1
			for p_player: Dictionary in players:
				if p_player.id == player_id:
					p_player["level_pass_count"] += 1
					Log.i("Player %s passed %s's level." % [format_player(p_player.name, p_player.id), format_player(p_author["name"], p_author["id"])])
		else:
			p_author["level_cause_death"] += 1
			for p_player: Dictionary in players:
				if p_player.id == player_id:
					Log.i("Player %s died in %s's level." % [format_player(p_player.name, p_player.id), format_player(p_author["name"], p_author["id"])])


@rpc("any_peer", "call_local")
func reach_end(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	for p: Dictionary in players:
		if p.id == player_id:
			p.reach_end = true
			Log.i("玩家 %s 已经玩过了所有关卡！" % [format_player(p.name, p.id)])
			break
	
@rpc("authority", "call_local")
func store_level_results(players: Array) -> void:
	Log.i("开始展示结果！！")
	for p: Dictionary in players:
		Log.i("%s 的关卡通过率：%s%%  关卡通过数：%d  总积分：%d" % [format_player(p["name"], p["id"]), str(round(p["clear_rate"] * 100000.0) / 1000.0), p["level_pass_count"], p["score"]])
	emit_signal("result_updated", players)
	for p: Dictionary in players:
		var level_file_path: String = p["level_file_name"]
		var pass_count: int = p["level_cause_pass"]
		var death_count: int = p["level_cause_death"]
		var file: FileAccess = FileAccess.open(level_file_path, FileAccess.READ)
		if not file:
			var err: int = FileAccess.get_open_error()
			Log.e("Failed to open level file: %s, error: %d" % [level_file_path, err])
			continue
		var content: String = file.get_as_text()
		file.close()
		if content.is_empty():
			Log.e("Level file is empty: %s" % [level_file_path])
			continue
		var json: JSON = JSON.new()
		var error: int = json.parse(content)
		
		if error != OK:
			push_error("Failed to parse level data JSON: %s" % level_file_path)
			continue
		
		var level_data_dict: Dictionary = json.data

		level_data_dict["pass_count"] = pass_count
		level_data_dict["death_count"] = death_count

		var level_data_json: String = JSON.stringify(level_data_dict, "")
		var tmp_file_path: String = level_file_path + ".tmp"
		var write_file: FileAccess = FileAccess.open(tmp_file_path, FileAccess.WRITE)
		if not write_file:
			var wr_err: int = FileAccess.get_open_error()
			Log.e("Failed to open file for writing: %s, error: %d" % [tmp_file_path, wr_err])
			continue
		write_file.store_string(level_data_json)
		write_file.close()
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			var rename_err: int = dir.rename(tmp_file_path, level_file_path)
			if rename_err != OK:
				Log.e("Rename failed: %s -> %s, error: %d" % [tmp_file_path, level_file_path, rename_err])

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func send_ani_sprite_data(player_id: int, current_level: int, ani_pos: Vector2, suit: PlayerSuit.SuitType, power: PlayerSuit.PowerupType, animation: StringName, frame: int, flip_h: bool, is_dead: bool, scale: Vector2, rotation: float) -> void:
	#print("[接收] 来自玩家 ", player_name, " 的动画坐标数据：", ani_pos)
	if current_level_count != current_level:
		return
	if not mp_ani_manager:
		#print("mp_ani_manager is null")
		return
	if not is_instance_valid(mp_ani_manager):
		Log.i("mp_ani_manager is not valid")
		return
	for ani: AnimatedSprite2D in mp_ani_manager.anis:
		if ani.has_meta("player_id"):
			if ani.get_meta("player_id") != player_id:
				continue
			# 位置
			ani.global_position = ani_pos
			# 缩放
			ani.scale = scale
			# 旋转
			ani.rotation = rotation
			# 名称
			var why_control_hasnt_global_rotation: Node2D = ani.get_node("%WhyControlHasntGlobalRotation")
			why_control_hasnt_global_rotation.global_rotation = 0.0		# 方便阅读
			var label: Label = ani.get_node("%PlayerNameLabel")
			for p: Dictionary in players:
				if p.id == player_id:
					label.text = str(p.name)
					break
			# 死亡
			if is_dead:
				ani.sprite_frames = player_dead_spritesframe
				ani.position += Vector2(0.0, 20.0).rotated(rotation)
				break
			# 套装
			match suit:
				PlayerSuit.SuitType.SMALL:
					ani.sprite_frames = player_small_spritesframe
				PlayerSuit.SuitType.SUPER:
					ani.sprite_frames = player_super_spritesframe
				PlayerSuit.SuitType.POWERED:
					match power:
						PlayerSuit.PowerupType.FIREBALL:
							ani.sprite_frames = player_fireball_spritesframe
						PlayerSuit.PowerupType.BEETROOT:
							ani.sprite_frames = player_beetroot_spritesframe
						PlayerSuit.PowerupType.LUI:
							ani.sprite_frames = player_lui_spritesframe
						PlayerSuit.PowerupType.BIG:
							ani.sprite_frames = player_big_spritesframe
						PlayerSuit.PowerupType.BEE:
							ani.sprite_frames = player_bee_spritesframe
						PlayerSuit.PowerupType.CLOUD:
							ani.sprite_frames = player_cloud_spritesframe
			#print("来自玩家 ", player_id, " 的动画套装数据：", suit, power)
			# 动画序列、帧、方向
			ani.animation = animation
			ani.frame = frame
			ani.flip_h = flip_h
			#print("[显示] 来自玩家 ", player_name, " 的动画坐标数据：", ani_pos)
			break
		else:
			ani.set_meta("player_id", player_id)
			break

func _get_tag(player_device_id: String) -> String:
	if player_device_id.is_empty():
		return "?????"
	return player_device_id.substr(0, 5)

func get_device_tag() -> String:
	var unique_id: String = OS.get_unique_id()
	if unique_id == "":
		return "?????"
	unique_id = unique_id.replace("{", "").replace("}", "").replace("-", "")
	return unique_id.substr(0, 5)

func format_player(p_name: Variant, p_id: Variant) -> String:
	return "[%s] %s (%s)" % [get_player_device_tag(p_id), p_name, p_id]

func get_player_device_tag(player_id: Variant) -> String:
	for p: Dictionary in players:
		if p.get("id") == player_id:
			return _get_tag(str(p.get("device_id", "")))
	return "?????"

func print_players() -> void:
	for p: Dictionary in players:
		var lv: String = p.level_data
		var lv_len: int = lv.length()
		if lv_len > 100:
			lv = lv.substr(0, 100) + "..."
		Log.i(" %s" % [format_player(p.name, p.id)])
		Log.i("   ready=%s  end=%s  file=%s" % [p.is_ready_to_start, p.reach_end, p.level_file_name])
		Log.i("   level_data[%d]: %s" % [lv_len, lv])
		print("")

func restore_origin_player_data() -> void:
	for p: Dictionary in players:
		p.level_file_name = "invalid"
		p.level_data = "invalid"
		p.is_ready_to_start = false
		p.is_ready_to_finish = false
		p.ready = false
		p.reach_end = false
		p.level_cause_pass = 0
		p.level_cause_death = 0
		p.level_pass_count = 0
		p.clear_rate = 0.0
		p.score = 0
	player.level_file_name = "invalid"
	player.level_data = "invalid"
	player.is_ready_to_start = false
	player.is_ready_to_finish = false
	player.ready = false
	player.reach_end = false
	player.level_cause_pass = 0
	player.level_cause_death = 0
	player.level_pass_count = 0
	player.clear_rate = 0.0
	player.score = 0

@rpc("any_peer", "call_local")
func sync_origin_player_data() -> void:
	if not multiplayer.is_server():
		return
	# 同步完整的玩家列表给所有客户端
	sync_players_list.rpc(players)
	emit_signal("players_updated")
	Log.i("已返回标题界面，并重新同步玩家列表数据：")
	print_players()

@rpc("any_peer", "call_local")
func get_ready(p_id: int, is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	for p: Dictionary in players:
		if p.id == p_id:
			p.is_ready_to_start = is_ready
			if is_ready:
				Log.i("玩家 %s 已就绪" % [format_player(p.name, p.id)])
			else:
				Log.i("玩家 %s 未就绪" % [format_player(p.name, p.id)])
			sync_players_list.rpc(players)
			break

## 编辑房间：某个玩家按下“准备完毕”（本局编辑器时间结束前的提前量）
@rpc("any_peer", "call_local")
func set_edit_ready(p_id: int, is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	for p: Dictionary in players:
		if p.id == p_id:
			p.is_ready_to_finish = is_ready
			if is_ready:
				Log.i("玩家 %s 已完成关卡编辑" % [format_player(p.name, p.id)])
			else:
				Log.i("玩家 %s 取消了完成编辑状态" % [format_player(p.name, p.id)])
			sync_players_list.rpc(players)
			break
	_check_all_edit_ready()

## 仅主机有效：所有玩家都完成编辑时通知提前结束倒计时
func _check_all_edit_ready() -> void:
	if not multiplayer.is_server() or not is_in_game or players.is_empty():
		return
	for p: Dictionary in players:
		var player_finished: bool = p.get("is_ready_to_finish", false)
		if not player_finished:
			return
	Log.i("所有玩家都已完成关卡编辑，提前结束倒计时。")
	edit_all_ready.emit()

@rpc("any_peer", "call_local", "reliable", 10)
func send_message(p_id: int, unique_id: String, msg: String) -> void:
	if not multiplayer.is_server():
		return
	var p_name: String = "invalid_name"
	for p: Dictionary in players:
		if p.id == p_id:
			p_name = str(p.name)
			break
	var time_str: String = Time.get_time_string_from_system(false)
	messages.append(
		{
			"cnt": msg_cnt,
			"player_id": p_id, "message": msg,
			"unique_id": unique_id,
			"player_name": p_name,
			"msg": msg,
			"time": time_str,
			"displayed": false,
		}
	)
	msg_cnt += 1
	sync_messages.rpc(messages)

@rpc("authority", "call_local", "reliable", 10)
func sync_messages(msgs: Array) -> void:
	messages = msgs
	emit_signal("messages_updated")