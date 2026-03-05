extends Node

class_name MultiplayerManager

signal players_updated

signal game_in_progress_hint

signal timeout_save

signal result_updated

signal play_sound_joined
signal play_sound_exited

@export var player_dead_spritesframe : SpriteFrames

var local_port
# 端口使用Sakura Frp隧道配置的远程端口
var remote_port
# Sakura Frp提供的域名
var frp_domain = ""
var player_name = ""

var game_start_time : String

# 玩家列表，仅由主机(host)保持权威，直到传输关卡数据之前
var players = []:
	set(value):
		print("[%s] players set player size: " % Time.get_time_string_from_system(), players.size())
		for p in players:
			print("[%s] players set player name: " % Time.get_time_string_from_system(), p.name)
		print("[%s] players set value size: " % Time.get_time_string_from_system(), value.size())
		for v in value:
			print("[%s] players set value player name: " % Time.get_time_string_from_system(), v.name)
		if players.size() < value.size():
			emit_signal("play_sound_joined")
			print("[%s] play sound joined" % Time.get_time_string_from_system())
		if players.size() > value.size():
			emit_signal("play_sound_exited")
			print("[%s] play sound exited" % Time.get_time_string_from_system())
		players = value

var random_levels = []
var current_level_count : int = 0

var total_levels : int = 0

var level_results = []

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
	"level_file_name": "invalid",
	"level_data": "invalid",
	"ready": false,
	"reach_end": false,
	"level_cause_pass": 0,
	"level_cause_death": 0,
	"level_pass_count": 0,
	"clear_rate": 0.0,
	"score": 0,
}


func _ready():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	multiplayer.connected_to_server.connect(func(): print("[%s] 连接成功" % Time.get_time_string_from_system()))
	multiplayer.connection_failed.connect(func(): print("[%s] 连接失败" % Time.get_time_string_from_system()))
	multiplayer.server_disconnected.connect(func(): print("[%s] 服务器断开" % Time.get_time_string_from_system()))

func _on_host_button_pressed():
	# 主机端代码通常不需要修改，仍监听本地端口
	var peer = ENetMultiplayerPeer.new()
	# 注意：这里监听的端口是本地端口，需要与FRP隧道配置的"本地端口"一致
	peer.create_server(local_port, 20)
	multiplayer.multiplayer_peer = peer

	player.id = multiplayer.get_unique_id()
	player.name = player_name

	players.append(player)
	emit_signal("players_updated")
	print("[%s] 主机已启动。" % Time.get_time_string_from_system())
	print("[%s] 玩家ID：" % Time.get_time_string_from_system(), multiplayer.get_unique_id())
	print("[%s] 玩家名称：" % Time.get_time_string_from_system(), player_name)

func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	
	print("[%s] 连接IP：" % Time.get_time_string_from_system(), frp_domain)
	print("[%s] 连接端口：" % Time.get_time_string_from_system(), remote_port)
	print("[%s] 玩家ID：" % Time.get_time_string_from_system(), multiplayer.get_unique_id())
	print("[%s] 玩家名称：" % Time.get_time_string_from_system(), player_name)

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

@rpc("authority", "call_remote")
func inform_late_player() -> void:
	push_warning("已连接主机。但该房间游戏已经开始。即将断开连接。")
	emit_signal("game_in_progress_hint")
	disconnect_and_cleanup()

@rpc("authority", "call_local")
func player_joined(player_info):
	# 所有对等体都会收到这个消息
	print("id：", player_info.id, " 名称：", player_info.name, " 已加入")

@rpc("authority", "call_local")
func sync_players_list(players_list):
	# 所有客户端接收并更新玩家列表
	players = players_list
	emit_signal("players_updated")
	print("玩家列表：")
	print(players)

func _on_peer_connected(_id: int):
	# 当有新对等体连接时，如果是主机，不需要额外处理
	# 因为 register_player_on_host 已经处理了逻辑
	pass

func _on_peer_disconnected(id: int):
	# 当对等体断开连接时
	if multiplayer.is_server():
		# 服务器：从 players 列表中移除离开的玩家
		# 这样写是为了触发 players 的 set 方法，因为 Array.append() 不会触发 set 方法
		var p_list = players.duplicate()
		for i in range(p_list.size()):
			if p_list[i].id == id:
				p_list.remove_at(i)
				players = p_list
				break
		
		emit_signal("players_updated")
		print("玩家 ", id, " 已离开")
		# 通知其他客户端更新玩家列表
		if players.size() > 0:
			sync_players_list.rpc(players)

# 服务器通知所有客户端退出房间
@rpc("authority", "call_local")
func server_closing():
	print("服务器即将关闭")
	# 隐藏 PlayerPage
	var player_page = get_node_or_null("/root/Title/GameRoomSize/PlayerPage")
	if player_page:
		player_page.visible = false
	players = []
	emit_signal("players_updated")
	# 断开连接
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

# 断开连接并清理
func disconnect_and_cleanup():
	players = []
	emit_signal("players_updated")
	if multiplayer.is_server():
		# 服务器：通知所有客户端（包括自己）
		server_closing.rpc()
	else:
		# 客户端：直接断开连接，服务器会通过 peer_disconnected 信号检测
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

@rpc("authority")
func edit_time_out():
	emit_signal("timeout_save")

@rpc("any_peer", "call_local")
func transfer_level_data(player_id: int, level_file_name: String, level_data: String) -> void:
	for p in players:
		if p.id == player_id:
			p.level_file_name = level_file_name
			p.level_data = level_data
			if p.id == player.id:
				print("已将自己的关卡数据加入玩家列表数据")
			else:
				print("已接收玩家 ", p.name, " 的关卡数据")
			break

@rpc("any_peer", "call_local")
func my_players_data_are_ready(player_id: int) -> void:
	for p in players:
		if p.id == player_id:
			p.ready = true
			print("玩家 ", player_id, " 已准备就绪")
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
					print("Player ", p_player.name, " passed ", p_author["name"], "'s level.")
		else:
			p_author["level_cause_death"] += 1
			for p_player in players:
				if p_player.id == player_id:
					print("Player ", p_player.name, " died in ", p_author["name"], "'s level.")


@rpc("any_peer", "call_local")
func reach_end(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	for p in players:
		if p.id == player_id:
			p.reach_end = true
			print("玩家 ", p.name, " 已经玩过了所有关卡！")
			break
	
@rpc("authority", "call_local")
func store_level_results(players) -> void:
	print("开始展示结果！！")
	for p in players:
		print(p["name"], "的关卡通过率：", round(p["clear_rate"] * 100000.0) / 1000.0, "%",
		" 关卡通过数：", p["level_pass_count"], " 总积分：", p["score"])
	emit_signal("result_updated", players)
	for p in players:
		var level_file_path = p["level_file_name"]
		var pass_count = p["level_cause_pass"]
		var death_count = p["level_cause_death"]
		var file = FileAccess.open(level_file_path, FileAccess.READ_WRITE)
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		
		if error != OK:
			push_error("Failed to parse level data JSON.")
			var err = FileAccess.get_open_error()
			if err != OK:
				print("Error loading file:", err)
			return
		
		var level_data_dict = json.data

		level_data_dict["pass_count"] = pass_count
		level_data_dict["death_count"] = death_count

		var level_data_json = JSON.stringify(level_data_dict, "")
		file.store_string(level_data_json)
		file.close()

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func send_ani_sprite_data(player_id: int, player_name: String, current_level: int, ani_pos: Vector2, suit, power, animation, frame, flip_h, is_dead: bool) -> void:
	#print("[接收] 来自玩家 ", player_name, " 的动画坐标数据：", ani_pos)
	if current_level_count != current_level:
		return
	if not mp_ani_manager:
		#print("mp_ani_manager is null")
		return
	if not is_instance_valid(mp_ani_manager):
		print("mp_ani_manager is not valid")
		return
	for ani in mp_ani_manager.anis:
		if ani.has_meta("player_id"):
			if ani.get_meta("player_id") != player_id:
				continue
			ani.global_position = ani_pos
			if is_dead:
				ani.sprite_frames = player_dead_spritesframe
				ani.position.y += 20.0
				continue
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
			ani.animation = animation
			ani.frame = frame
			ani.flip_h = flip_h
			var label = ani.get_node("UiLabel") as Label
			label.text = player_name
			#print("[显示] 来自玩家 ", player_name, " 的动画坐标数据：", ani_pos)
			break
		else:
			ani.set_meta("player_id", player_id)
			break

func restore_origin_player_data() -> void:
	for p in players:
		p.level_file_name = "invalid"
		p.level_data = "invalid"
		p.ready = false
		p.reach_end = false
		p.level_cause_pass = 0
		p.level_cause_death = 0
		p.level_pass_count = 0
		p.clear_rate = 0.0
		p.score = 0

@rpc("authority", "call_local")
func sync_origin_player_data() -> void:
	# 同步完整的玩家列表给所有客户端
	sync_players_list.rpc(players)
	emit_signal("players_updated")
	print("已返回标题界面，并重新同步玩家列表数据：")
	print(players)