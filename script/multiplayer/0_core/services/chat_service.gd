class_name ChatService
extends Node

## 快捷消息。客户端只发用语序号，各端按自己的语言渲染。
##
## 自定义文本消息保留实现但默认封存（调用方 message_sender.gd 仍被禁用）。

signal messages_updated

var messages: Array = []
var msg_cnt: int = 0

var _manager: MultiplayerManager


func setup(manager: MultiplayerManager) -> void:
	_manager = manager


func clear() -> void:
	if messages.is_empty():
		return
	messages.clear()
	msg_cnt = 0
	messages_updated.emit()


func send_quick(quick_id: int) -> void:
	if _manager == null:
		return
	if not QuickMessageTable.is_valid_id(quick_id):
		push_warning("无效的快捷用语序号：%d" % quick_id)
		return
	if _manager.net.is_server():
		_apply_quick(_manager.player.id, _manager.get_device_tag(), quick_id)
	else:
		c2s_chat_quick.rpc_id(1, _manager.get_device_tag(), quick_id)


## 已封存：自定义文本。恢复时由 message_sender.gd 调用。
func send_custom_text(text: String) -> void:
	if _manager == null or text.is_empty():
		return
	if _manager.net.is_server():
		_apply_text(_manager.player.id, _manager.get_device_tag(), text)
	else:
		c2s_chat_text.rpc_id(1, _manager.get_device_tag(), text)


func _apply_quick(player_id: int, unique_id: String, quick_id: int) -> void:
	var profile: PlayerProfile = _manager.registry.get_player(player_id)
	var player_name: String = "invalid_name" if profile == null else profile.name
	var avatar_id: String = "" if profile == null else profile.avatar_id
	messages.append(
		{
			"cnt": msg_cnt,
			"player_id": player_id,
			"message": "",
			"unique_id": unique_id,
			"player_name": player_name,
			"avatar_id": avatar_id,
			"msg": "",
			"quick_id": quick_id,
			"time": Time.get_time_string_from_system(false),
			"displayed": false,
		}
	)
	msg_cnt += 1
	s2c_chat_sync.rpc(messages)


func _apply_text(player_id: int, unique_id: String, text: String) -> void:
	var profile: PlayerProfile = _manager.registry.get_player(player_id)
	var player_name: String = "invalid_name" if profile == null else profile.name
	messages.append(
		{
			"cnt": msg_cnt,
			"player_id": player_id,
			"message": text,
			"unique_id": unique_id,
			"player_name": player_name,
			"msg": text,
			"time": Time.get_time_string_from_system(false),
			"displayed": false,
		}
	)
	msg_cnt += 1
	s2c_chat_sync.rpc(messages)


@rpc("any_peer", "call_remote", "reliable", 3)
func c2s_chat_quick(unique_id: String, quick_id: int) -> void:
	if _manager == null or not _manager.net.is_server():
		return
	if not QuickMessageTable.is_valid_id(quick_id):
		return
	_apply_quick(multiplayer.get_remote_sender_id(), unique_id, quick_id)


@rpc("any_peer", "call_remote", "reliable", 3)
func c2s_chat_text(unique_id: String, text: String) -> void:
	if _manager == null or not _manager.net.is_server():
		return
	if text.is_empty() or text.length() > 200:
		return
	_apply_text(multiplayer.get_remote_sender_id(), unique_id, text)


@rpc("authority", "call_local", "reliable", 3)
func s2c_chat_sync(msgs: Array) -> void:
	messages = msgs
	messages_updated.emit()
