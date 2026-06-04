extends Node

class_name MultiplayerManager

signal players_updated

signal game_in_progress_hint

signal timeout_save

signal result_updated

signal play_sound_joined
signal play_sound_exited

signal messages_updated

@export var player_dead_spritesframe : SpriteFrames

var local_port
# 端口使用Sakura Frp隧道配置的远程端口
var remote_port
# Sakura Frp提供的域名
var frp_domain: String = ""
var player_name: String = ""

var game_start_time : String

var messages = []
var msg_cnt: int = 0

# 玩家列表，仅由主机(host)保持权威，直到传输关卡数据之前
var players = []:
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

var random_levels = []
var current_level_count : int = 0

var total_levels : int = 0

var level_results = []

var _pending_disconnect_reasons = {}

var is_in_game : bool = false:
	set(value):
		is_in_game = value
		random_levels.clear()
		current_level_count = 0
		total_levels = 0
		level_results.clear()
		GameModeSingleton.game_mode = GameModeSingleton.GameModeType.EDIT

@export var player_small_spritesframe : SpriteFrames
@export var player_super_spritesframe : SpriteFrames
@export var player_fireball_spritesframe : SpriteFrames
@export var player_beetroot_spritesframe : SpriteFrames
@export var player_lui_spritesframe : SpriteFrames

var mp_ani_manager

# 自己的玩家信息
var player = {
	"id": "invalid",
	"name": "invalid",
	"is_ready_to_start": false,
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


func _ready():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	multiplayer.connected_to_server.connect(func(): print("[%s] 连接成功" % Time.get_time_string_from_system()))
	multiplayer.connection_failed.connect(func(): print("[%s] 连接失败" % Time.get_time_string_from_system()))
	multiplayer.server_disconnected.connect(func(): print("[%s] 服务器断开" % Time.get_time_string_from_system()))

	device_id = get_device_tag()

func _on_host_button_pressed():
	# 主机端代码通常不需要修改，仍监听本地端口
	var peer = ENetMultiplayerPeer.new()
	# 注意：这里监听的端口是本地端口，需要与FRP隧道配置的"本地端口"一致
	peer.create_server(local_port, 20)
	multiplayer.multiplayer_peer = peer

	player.id = multiplayer.get_unique_id()
	player.name = player_name
	player.device_id = device_id

	players.append(player)
	emit_signal("players_updated")
	print("[%s] 主机已启动。" % Time.get_time_string_from_system())
	print("[%s] 主机玩家：%s" % [Time.get_time_string_from_system(), format_player(player_name, player.id)])

func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	
	print("[%s] 连接IP：" % Time.get_time_string_from_system(), frp_domain)
	print("[%s] 连接端口：" % Time.get_time_string_from_system(), remote_port)
	print("[%s] 本地玩家：%s" % [Time.get_time_string_from_system(), format_player(player_name, multiplayer.get_unique_id())])

	var error = peer.create_client(frp_domain, remote_port)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("[%s] 正在连接到服务器: " % Time.get_time_string_from_system(), frp_domain)
	else:
		print("[%s] 连接失败，错误信息: " % Time.get_time_string_from_system(), error)

func _on_connected_to_server():
	# 客户端连接成功后，向主机发送自己的玩家信息
	player.id = multiplayer.get_unique_id()
	player.name = player_name
	player.device_id = device_id
	# 仅向主机发送加入请求
	register_player_on_host.rpc_id(1, player)

@rpc("any_peer", "call_remote")
func register_player_on_host(player_info):
	# 只有主机执行此函数
	if not multiplayer.is_server():
		return
	
	if is_in_game:
		push_warning(player_info.id, player_info.name, "试图加入游戏，但是游戏开始了——")
		inform_late_player.rpc_id(player_info.id)
		return

	# 更新主机本地的玩家列表
	# 这样写是为了触发 players 的 set 方法，因为 Array.append() 不会触发 set 方法
	var p_list = players.duplicate()
	p_list.append(player_info)
	
	# 通知所有对等体有新玩家加入
	player_joined.rpc(player_info)
	
	# 同步完整的玩家列表给所有客户端
	sync_players_list.rpc(p_list)

	# 同步所有聊天记录给新客户端
	sync_messages.rpc(messages)

@rpc("authority", "call_remote")
func inform_late_player() -> void:
	push_warning("已连接主机。但该房间游戏已经开始。即将断开连接。")
	emit_signal("game_in_progress_hint")
	disconnect_and_cleanup("游戏已开始，拒绝加入")

@rpc("authority", "call_local")
func player_joined(player_info):
	var tag = _get_tag(player_info.get("device_id", ""))
	print("[%s] 玩家 [%s] %s (%s) 已加入" % [Time.get_time_string_from_system(), tag, player_info.name, player_info.id])

@rpc("authority", "call_local")
func sync_players_list(players_list):
	# 所有客户端接收并更新玩家列表
	players = players_list
	emit_signal("players_updated")
	print_players()

func _on_peer_connected(_id: int):
	# 当有新对等体连接时，如果是主机，不需要额外处理
	# 因为 register_player_on_host 已经处理了逻辑
	pass

func _on_peer_disconnected(id: int):
	# 当对等体断开连接时
	if multiplayer.is_server():
		var p_name = "?"
		var p_device_id = ""
		for p in players:
			if p.id == id:
				p_name = p.name
				p_device_id = p.get("device_id", "")
				break
		
		# 服务器：从 players 列表中移除离开的玩家
		# 这样写是为了触发 players 的 set 方法，因为 Array.append() 不会触发 set 方法
		var p_list = players.duplicate()
		for i in range(p_list.size()):
			if p_list[i].id == id:
				p_list.remove_at(i)
				players = p_list
				break
		
		emit_signal("players_updated")
		var reason = _pending_disconnect_reasons.get(id, "意外断开连接")
		_pending_disconnect_reasons.erase(id)
		var tag = _get_tag(p_device_id)
		push_warning("[%s] 玩家 [%s] %s (%s) — %s" % [Time.get_time_string_from_system(), tag, p_name, id, reason])
		# 通知其他客户端更新玩家列表
		if players.size() > 0:
			sync_players_list.rpc(players)

# 服务器通知所有客户端退出房间
@rpc("authority", "call_local")
func server_closing():
	print("[%s] 服务器即将关闭" % Time.get_time_string_from_system())
	# 隐藏 PlayerPage
	var player_page = get_node_or_null("/root/Title/GameRoomSize/PlayerPage")
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
	var sender_id = multiplayer.get_remote_sender_id()
	_pending_disconnect_reasons[sender_id] = reason

# 断开连接并清理
func disconnect_and_cleanup(reason := "意外断开连接") -> void:
	var tag = format_player(player.name, player.id)
	if multiplayer.is_server():
		print("[%s] 玩家 %s — %s" % [Time.get_time_string_from_system(), tag, reason])
		server_closing.rpc()
	else:
		notify_disconnect.rpc_id(1, reason)
		for i in range(2):
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
func edit_time_out():
	emit_signal("timeout_save")

@rpc("any_peer", "call_local")
func transfer_level_data(player_id: int, level_file_name: String, level_data_bytes_compressed: PackedByteArray) -> void:
	# 防止结束时主机发送不带关卡数据的玩家信息，导致空关卡数据覆盖本地文件
	if player.reach_end:
		return
	if level_file_name == "invalid" or level_file_name.is_empty():
		push_error("[%s] transfer_level_data received invalid file name" % Time.get_time_string_from_system())
		return
	for p in players:
		if p.id == player_id:
			p.level_file_name = level_file_name
			
			# 1. 解压
			var level_data_bytes = level_data_bytes_compressed.decompress_dynamic(-1, FileAccess.CompressionMode.COMPRESSION_DEFLATE)
			if level_data_bytes.is_empty():
				push_error("[%s] 解压失败，压缩数据大小：%d 字节" % [Time.get_time_string_from_system(), level_data_bytes_compressed.size()])
				p.level_data = "invalid"
				return
			
			print("[%s] 解压成功，字节数：%d" % [Time.get_time_string_from_system(), level_data_bytes.size()])
			
			# 2. 转 UTF-8 字符串
			var level_json = level_data_bytes.get_string_from_utf8()
			if level_json.is_empty():
				push_error("[%s] UTF-8 转换失败，字节数据可能不是有效文本" % Time.get_time_string_from_system())
				p.level_data = "invalid"
				return
			
			p.level_data = level_json
			emit_signal("players_updated")
			
			if p.id == player.id:
				print("[%s] 已将自己的关卡数据加入玩家列表数据" % Time.get_time_string_from_system())
			else:
				print("[%s] 已接收玩家 %s 的关卡数据，JSON 长度：%d" % [Time.get_time_string_from_system(), format_player(p.name, p.id), level_json.length()])
			break

@rpc("any_peer", "call_local")
func my_players_data_are_ready(player_id: int) -> void:
	for p in players:
		if p.id == player_id:
			p.ready = true
			print("[%s] 玩家 %s 已准备就绪" % [Time.get_time_string_from_system(), format_player(p.name, p.id)])
			break

@rpc("authority", "call_local")
func lets_play_together(rnd_levels: Array) -> void:
	self.random_levels = rnd_levels
	if multiplayer.is_server():
		level_results = []
		for level in rnd_levels:
			level_results.append({
				"level": level,
				"pass_count": 0,
				"death_count": 0,
			})
	current_level_count = 0
	total_levels = rnd_levels.size()
	var game_mode = GameModeSingleton
	game_mode.game_mode = GameModeSingleton.GameModeType.PLAY
	var fc = func():
		get_tree().change_scene_to_file("uid://cxvueju65b3qv")
	fc.call_deferred()

@rpc("any_peer", "call_local")
func level_add_pass_count(level, passed : bool, player_id: int) -> void:
	if not multiplayer.is_server():
		return
	for p_author in players:
		if p_author["level_file_name"] != level:
			continue
		if passed:
			p_author["level_cause_pass"] += 1
			for p_player in players:
				if p_player.id == player_id:
					p_player["level_pass_count"] += 1
					print("[%s] Player %s passed %s's level." % [Time.get_time_string_from_system(), format_player(p_player.name, p_player.id), format_player(p_author["name"], p_author["id"])])
		else:
			p_author["level_cause_death"] += 1
			for p_player in players:
				if p_player.id == player_id:
					print("[%s] Player %s died in %s's level." % [Time.get_time_string_from_system(), format_player(p_player.name, p_player.id), format_player(p_author["name"], p_author["id"])])


@rpc("any_peer", "call_local")
func reach_end(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	for p in players:
		if p.id == player_id:
			p.reach_end = true
			print("[%s] 玩家 %s 已经玩过了所有关卡！" % [Time.get_time_string_from_system(), format_player(p.name, p.id)])
			break
	
@rpc("authority", "call_local")
func store_level_results(players) -> void:
	print("[%s] 开始展示结果！！" % Time.get_time_string_from_system())
	for p in players:
		print("[%s] %s 的关卡通过率：%s%%  关卡通过数：%d  总积分：%d" % [Time.get_time_string_from_system(), format_player(p["name"], p["id"]), str(round(p["clear_rate"] * 100000.0) / 1000.0), p["level_pass_count"], p["score"]])
	emit_signal("result_updated", players)
	for p in players:
		var level_file_path = p["level_file_name"]
		var pass_count = p["level_cause_pass"]
		var death_count = p["level_cause_death"]
		var file = FileAccess.open(level_file_path, FileAccess.READ)
		if not file:
			var err = FileAccess.get_open_error()
			push_error("[%s] Failed to open level file: %s, error: %d" % [Time.get_time_string_from_system(), level_file_path, err])
			continue
		var content = file.get_as_text()
		file.close()
		if content.is_empty():
			push_error("[%s] Level file is empty: %s" % [Time.get_time_string_from_system(), level_file_path])
			continue
		var json = JSON.new()
		var error = json.parse(content)
		
		if error != OK:
			push_error("Failed to parse level data JSON: %s" % level_file_path)
			continue
		
		var level_data_dict = json.data

		level_data_dict["pass_count"] = pass_count
		level_data_dict["death_count"] = death_count

		var level_data_json = JSON.stringify(level_data_dict, "")
		var tmp_file_path = level_file_path + ".tmp"
		var write_file = FileAccess.open(tmp_file_path, FileAccess.WRITE)
		if not write_file:
			var wr_err = FileAccess.get_open_error()
			push_error("[%s] Failed to open file for writing: %s, error: %d" % [Time.get_time_string_from_system(), tmp_file_path, wr_err])
			continue
		write_file.store_string(level_data_json)
		write_file.close()
		var dir = DirAccess.open("user://")
		if dir:
			var rename_err = dir.rename(tmp_file_path, level_file_path)
			if rename_err != OK:
				push_error("[%s] Rename failed: %s -> %s, error: %d" % [Time.get_time_string_from_system(), tmp_file_path, level_file_path, rename_err])

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func send_ani_sprite_data(player_id: int, current_level: int, ani_pos: Vector2, suit, power, animation, frame, flip_h, is_dead: bool, scale: Vector2) -> void:
	#print("[接收] 来自玩家 ", player_name, " 的动画坐标数据：", ani_pos)
	if current_level_count != current_level:
		return
	if not mp_ani_manager:
		#print("mp_ani_manager is null")
		return
	if not is_instance_valid(mp_ani_manager):
		print("[%s] mp_ani_manager is not valid" % Time.get_time_string_from_system())
		return
	for ani in mp_ani_manager.anis:
		if ani.has_meta("player_id"):
			if ani.get_meta("player_id") != player_id:
				continue
			# 位置
			ani.global_position = ani_pos
			# 缩放
			ani.scale = scale
			# 名称
			var label = ani.get_node("UiLabel") as Label
			for p in players:
				if p.id == player_id:
					label.text = p.name
					break
			# 死亡
			if is_dead:
				ani.sprite_frames = player_dead_spritesframe
				ani.position.y += 20.0
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
	var unique_id = OS.get_unique_id()
	if unique_id == "":
		return "?????"
	unique_id = unique_id.replace("{", "").replace("}", "").replace("-", "")
	return unique_id.substr(0, 5)

func format_player(p_name, p_id) -> String:
	return "[%s] %s (%s)" % [get_player_device_tag(p_id), p_name, p_id]

func get_player_device_tag(player_id: int) -> String:
	for p in players:
		if p.id == player_id:
			return p.device_id
	return "?????"

func print_players() -> void:
	for p in players:
		var lv = p.level_data
		var lv_len = lv.length()
		if lv_len > 100:
			lv = lv.substr(0, 100) + "..."
		print("[%s]  %s" % [Time.get_time_string_from_system(), format_player(p.name, p.id)])
		print("[%s]    ready=%s  end=%s  file=%s" % [Time.get_time_string_from_system(), p.is_ready_to_start, p.reach_end, p.level_file_name])
		print("[%s]    level_data[%d]: %s" % [Time.get_time_string_from_system(), lv_len, lv])
		print("")

func restore_origin_player_data() -> void:
	for p in players:
		p.level_file_name = "invalid"
		p.level_data = "invalid"
		p.is_ready_to_start = false
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
	print("[%s] 已返回标题界面，并重新同步玩家列表数据：" % Time.get_time_string_from_system())
	print_players()

@rpc("any_peer", "call_local")
func get_ready(p_id: int, is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	for p in players:
		if p.id == p_id:
			p.is_ready_to_start = is_ready
			if is_ready:
				print("[%s] 玩家 %s 已就绪" % [Time.get_time_string_from_system(), format_player(p.name, p.id)])
			else:
				print("[%s] 玩家 %s 未就绪" % [Time.get_time_string_from_system(), format_player(p.name, p.id)])
			sync_players_list.rpc(players)
			break

@rpc("any_peer", "call_local", "reliable", 10)
func send_message(p_id: int, unique_id: String, msg: String) -> void:
	if not multiplayer.is_server():
		return
	var p_name = "invalid_name"
	for p in players:
		if p.id == p_id:
			p_name = p.name
			break
	var time_str = Time.get_time_string_from_system(false)
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