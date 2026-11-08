class_name SessionRegistry
extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 房间玩家索引：id -> PlayerProfile。
##
## 替代原来在 MultiplayerManager 里到处 for 循环扫 Array[Dictionary] 的写法。
## 只负责保存与查找，不负责网络广播；广播由 LobbyService 完成。

signal player_added(id: int)
signal player_removed(id: int, display_name: String)
signal player_changed(id: int, group: StringName)
signal registry_reset()

var _players: Dictionary[int, PlayerProfile] = {}
var _order: Array[int] = []


func size() -> int:
	return _order.size()


func is_empty() -> bool:
	return _order.is_empty()


func has_player(id: int) -> bool:
	return _players.has(id)


func get_player(id: int) -> PlayerProfile:
	if not _players.has(id):
		return null
	return _players[id]


func ids() -> Array[int]:
	return _order.duplicate()


func all() -> Array[PlayerProfile]:
	var result: Array[PlayerProfile] = []
	for id: int in _order:
		var profile: PlayerProfile = _players[id]
		result.append(profile)
	return result


func add(profile: PlayerProfile) -> void:
	if profile == null:
		return
	if _players.has(profile.id):
		_players[profile.id] = profile
		player_changed.emit(profile.id, PlayerProfile.GROUP_ALL)
		return
	_players[profile.id] = profile
	_order.append(profile.id)
	player_added.emit(profile.id)


func remove(id: int) -> PlayerProfile:
	if not _players.has(id):
		return null
	var profile: PlayerProfile = _players[id]
	_players.erase(id)
	_order.erase(id)
	player_removed.emit(id, profile.name)
	return profile


func clear() -> void:
	if _players.is_empty() and _order.is_empty():
		return
	_players.clear()
	_order.clear()
	registry_reset.emit()


## 用主机下发的完整快照替换本地列表。
func replace_from_wire(list: Array) -> void:
	_players.clear()
	_order.clear()
	for entry: Variant in list:
		if not (entry is Dictionary):
			continue
		var data: Dictionary = entry
		var profile: PlayerProfile = PlayerProfile.from_wire(data)
		if profile.id == 0:
			continue
		if _players.has(profile.id):
			continue
		_players[profile.id] = profile
		_order.append(profile.id)
	registry_reset.emit()


## 应用一条增量。找不到玩家时返回 false。
func apply_wire(id: int, data: Dictionary) -> bool:
	if not _players.has(id):
		return false
	var profile: PlayerProfile = _players[id]
	profile.apply_wire(data)
	player_changed.emit(id, PlayerProfile.GROUP_ALL)
	return true


func notify_changed(id: int, group: StringName = PlayerProfile.GROUP_ALL) -> void:
	if not _players.has(id):
		return
	player_changed.emit(id, group)


func reset_match_state() -> void:
	for profile: PlayerProfile in all():
		profile.reset_match_state()
		player_changed.emit(profile.id, PlayerProfile.GROUP_ALL)


func host_player() -> PlayerProfile:
	for profile: PlayerProfile in all():
		if profile.is_host:
			return profile
	return null


func to_wire_list() -> Array:
	var result: Array = []
	for profile: PlayerProfile in all():
		result.append(profile.to_wire())
	return result
