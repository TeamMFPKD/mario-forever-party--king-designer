extends Node

## 标题页唯一的网络状态消费者。
##
## 网络层不再 get_node("/root/Title/...")；页面显隐全部由这里根据
## NetPeer / LobbyService 的信号处理。

const HOST_PAGE: String = "../GameRoomSize/HostPage"
const JOIN_PAGE: String = "../GameRoomSize/JoinPage"
const PLAYER_PAGE: String = "../GameRoomSize/PlayerPage"
const CLIENT_INVISIBLE_SET: String = "../ClientInvisibleNodeSet"
const TITLE_PAGE_MANAGER_GROUP: StringName = &"title_page_manager"

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
	_watch_page(_host_page)
	_watch_page(_join_page)
	_sync_from_state()


## 大厅页被关掉（退出动画播完、visible 变 false）时清掉「上次大厅页」记录。
## 否则下次标题场景重载（例如从百人团返回）时，_sync_from_state 会凭这条
## 陈旧记录把页面又自动弹回来。
func _watch_page(page: Control) -> void:
	if page == null:
		return
	page.visibility_changed.connect(_on_page_visibility_changed.bind(page))


func _on_page_visibility_changed(page: Control) -> void:
	if page == null or not is_instance_valid(page) or page.visible:
		return
	MPManager.clear_lobby_page()


func _sync_from_state() -> void:
	if MPManager.net != null and MPManager.net.is_online() and MPManager.registry.size() > 0:
		_show_player_page()
	elif MPManager.get_lobby_page() == MultiplayerManager.LobbyPage.HOST:
		_restore_page(_host_page)
	elif MPManager.get_lobby_page() == MultiplayerManager.LobbyPage.JOIN:
		_restore_page(_join_page)


func _show_player_page() -> void:
	_open_page(_player_page)
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
	# 自己主动退出（例如主机在玩家列表页点「退出」）不是房间丢失，
	# 页面已由退出按钮关掉，这里不要再把加入页弹出来。
	if MPManager.is_self_leaving():
		return
	_restore_page(_join_page)


func _restore_page(page: Control) -> void:
	_open_page(page)


## 页面显隐统一交给 TitlePageManager（它负责互斥与退出动画）；
## 没有管理器时（例如单独跑子场景）退回直接改 visible。
func _open_page(page: Control) -> void:
	if page == null or not is_instance_valid(page):
		return
	var manager: Node = get_tree().get_first_node_in_group(TITLE_PAGE_MANAGER_GROUP)
	if manager != null:
		manager.call("open_page", page)
		return
	page.visible = true
