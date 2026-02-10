extends Node

class_name MultiplayerManager

signal players_updated

var local_port
# 端口使用Sakura Frp隧道配置的远程端口
var remote_port
# Sakura Frp提供的域名
var frp_domain = ""
var player_name = ""

var game_start_time : String

# 玩家列表，仅由主机(host)保持权威
var players = []

func _ready():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	multiplayer.connected_to_server.connect(func(): print("连接成功"))
	multiplayer.connection_failed.connect(func(): print("连接失败"))
	multiplayer.server_disconnected.connect(func(): print("服务器断开"))

func _on_host_button_pressed():
	# 主机端代码通常不需要修改，仍监听本地端口
	var peer = ENetMultiplayerPeer.new()
	# 注意：这里监听的端口是本地端口，需要与FRP隧道配置的"本地端口"一致
	peer.create_server(local_port, 20)
	multiplayer.multiplayer_peer = peer
	var player = {
		"id": multiplayer.get_unique_id(),
		"name": player_name
	}
	players.append(player)
	emit_signal("players_updated")
	print("主机已启动。")
	print("玩家ID：", multiplayer.get_unique_id())
	print("玩家名称：", player_name)

func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	
	print("连接IP：", frp_domain)
	print("连接端口：", remote_port)
	print("玩家ID：", multiplayer.get_unique_id())
	print("玩家名称：", player_name)

	var error = peer.create_client(frp_domain, remote_port)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("正在连接到服务器: ", frp_domain)
	else:
		print("连接失败，错误信息: ", error)

func _on_connected_to_server():
	# 客户端连接成功后，向主机发送自己的玩家信息
	var player = {
		"id": multiplayer.get_unique_id(),
		"name": player_name
	}
	# 仅向主机发送加入请求
	register_player_on_host.rpc_id(1, player)

@rpc("any_peer", "call_remote")
func register_player_on_host(player_info):
	# 只有主机执行此函数
	if not multiplayer.is_server():
		return
	
	# 更新主机本地的玩家列表
	players.append(player_info)
	
	# 通知所有对等体有新玩家加入
	player_joined.rpc(player_info)
	
	# 同步完整的玩家列表给所有客户端
	sync_players_list.rpc(players)

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

func _on_peer_connected(id: int):
	# 当有新对等体连接时，如果是主机，不需要额外处理
	# 因为 register_player_on_host 已经处理了逻辑
	pass

func _on_peer_disconnected(id: int):
	# 当对等体断开连接时
	if multiplayer.is_server():
		# 服务器：从 players 列表中移除离开的玩家
		for i in range(players.size()):
			if players[i].id == id:
				players.remove_at(i)
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
	multiplayer.multiplayer_peer = null

# 客户端通知服务器自己即将离开
@rpc("any_peer", "call_remote")
func client_leaving(player_id: int):
	if not multiplayer.is_server():
		return
	
	# 从 players 列表中移除离开的玩家
	for i in range(players.size()):
		if players[i].id == player_id:
			players.remove_at(i)
			break
	
	emit_signal("players_updated")
	print("玩家 ", player_id, " 已离开")
	# 通知其他客户端更新玩家列表
	sync_players_list.rpc(players)

# 断开连接并清理
func disconnect_and_cleanup():
	if multiplayer.is_server():
		# 服务器：通知所有客户端（包括自己）
		server_closing.rpc()
	else:
		# 客户端：直接断开连接，服务器会通过 peer_disconnected 信号检测
		# 隐藏 PlayerPage
		var player_page = get_node_or_null("/root/Title/GameRoomSize/PlayerPage")
		if player_page:
			player_page.visible = false
		players = []
		emit_signal("players_updated")
		multiplayer.multiplayer_peer = null
