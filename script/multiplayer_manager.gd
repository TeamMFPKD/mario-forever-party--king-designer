extends Node

class_name MultiplayerManager

var local_port = 8914
# 端口使用Sakura Frp隧道配置的远程端口
var remote_port = 18857
# Sakura Frp提供的域名
var frp_domain = ""

func _ready():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	multiplayer.connected_to_server.connect(func(): print("✅ 连接成功"))
	multiplayer.connection_failed.connect(func(): print("❌ 连接失败"))
	multiplayer.server_disconnected.connect(func(): print("⚠️ 服务器断开"))

func _on_host_button_pressed():
	# 主机端代码通常不需要修改，仍监听本地端口
	var peer = WebSocketMultiplayerPeer.new()
	# 注意：这里监听的端口是本地端口，需要与FRP隧道配置的“本地端口”一致
	peer.create_server(local_port, "*")
	multiplayer.multiplayer_peer = peer
	print("主机已启动，等待FRP隧道连接...")

func _on_join_button_pressed():
	var peer = WebSocketMultiplayerPeer.new()
	
	# 使用 connect_to_url 并构建正确的 WebSocket URL
	# 格式：wss://域名:端口
	var connection_string = "wss://%s:%s" % [frp_domain, remote_port]
	print("连接域名：", frp_domain)
	print("连接端口：", remote_port)
	var error = peer.create_client(connection_string, TLSOptions.client_unsafe())
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("正在连接到服务器: ", connection_string)
	else:
		print("连接失败，错误代码: ", error)

func _on_connected_to_server():
	connected.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func connected():
	print("已连接")