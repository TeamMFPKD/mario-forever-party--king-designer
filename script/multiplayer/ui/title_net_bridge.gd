extends Node

## 标题页唯一的网络状态消费者。
##
## 网络层不再 get_node("/root/Title/...")；页面显隐全部由这里根据
## NetPeer / LobbyService 的信号处理。

const HOST_PAGE: String = "../GameRoomSize/HostPage"
const JOIN_PAGE: String = "../GameRoomSize/JoinPage"
const PLAYER_PAGE: String = "../GameRoomSize/PlayerPage"
const CLIENT_INVISIBLE_SET: String = "../ClientInvisibleNodeSet"

var _host_page: Control
var _join_page: Control
var _player_page: Control
var _client_invisible_set: Node


func _ready() -> void:
	_host_page = get_node_or_null(HOST_PAGE) as Control
	_join_page = get_node_or_null(JOIN_PAGE) as Control
	_player_page = get_node_or_null(PLAYER_PAGE) as Control
	_client_invisible_set = get_node_or_null(CLIENT_INVISIBLE_SET)

	MPManager.net.hosted.connect(_show_player_page)
	MPManager.net.joined.connect(_show_player_page)
	MPManager.net.connect_failed.connect(_on_join_failed)
	MPManager.net.server_lost.connect(_on_room_lost)
	MPManager.net.room_closed.connect(_on_room_lost)
	MPManager.lobby.join_rejected.connect(_on_join_rejected)
	_sync_from_state()


func _sync_from_state() -> void:
	if MPManager.net != null and MPManager.net.is_online() and MPManager.registry.size() > 0:
		_show_player_page()
	elif MPManager.get_lobby_page() == MultiplayerManager.LobbyPage.HOST:
		_restore_page(_host_page)
	elif MPManager.get_lobby_page() == MultiplayerManager.LobbyPage.JOIN:
		_restore_page(_join_page)


func _show_player_page() -> void:
	if _host_page:
		_host_page.visible = false
	if _join_page:
		_join_page.visible = false
	if _player_page:
		_player_page.visible = true
	if _client_invisible_set:
		if MPManager.net.is_server():
			_client_invisible_set.call("_on_nodes_visible_set")
		else:
			_client_invisible_set.call("_on_nodes_invisible_set")


func _on_join_failed(_reason: String) -> void:
	_restore_page(_join_page)


func _on_join_rejected(_reason: String) -> void:
	_restore_page(_join_page)


func _on_room_lost() -> void:
	_restore_page(_join_page)


func _restore_page(page: Control) -> void:
	if _player_page:
		_player_page.visible = false
	if _host_page:
		_host_page.visible = page == _host_page
	if _join_page:
		_join_page.visible = page == _join_page
