extends Node

class_name MultiplayerManager

var local_port = 8914
# 端口使用Sakura Frp隧道配置的远程端口
var remote_port = 18857
# Sakura Frp提供的域名
var frp_domain = ""

func _ready():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	multiplayer.connected_to_server.connect(func(): print("连接成功"))
	multiplayer.connection_failed.connect(func(): print("连接失败"))
	multiplayer.server_disconnected.connect(func(): print("服务器断开"))

func _on_host_button_pressed():
	# 主机端代码通常不需要修改，仍监听本地端口
	var peer = ENetMultiplayerPeer.new()
	# 注意：这里监听的端口是本地端口，需要与FRP隧道配置的“本地端口”一致
	peer.create_server(local_port, 20)
	multiplayer.multiplayer_peer = peer
	print("主机已启动。")

func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	
	print("连接IP：", frp_domain)
	print("连接端口：", remote_port)
	var error = peer.create_client(frp_domain, remote_port)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("正在连接到服务器: ", frp_domain)
	else:
		print("连接失败，错误代码: ", error)

func _on_connected_to_server():
	print("如果看见这条消息，那么应该还额外 print 一行消息表示 @rpc 函数被调用")
	connected.rpc()

@rpc("any_peer", "call_local")
func connected():
	print("已连接。这是远程调用的 @rpc 注解函数。你胜利了！")
	