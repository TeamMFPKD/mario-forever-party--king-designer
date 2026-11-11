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


## notify=false 用于掉线重连换 peer id：记录被移走但玩家没有离开房间，
## 不能弹「玩家离开」提示。
func remove(id: int, notify: bool = true) -> PlayerProfile:
	if not _players.has(id):
		return null
	var profile: PlayerProfile = _players[id]
	_players.erase(id)
	_order.erase(id)
	if notify:
		player_removed.emit(id, profile.name)
	return profile


func clear() -> void:
	if _players.is_empty() and _order.is_empty():
		return
	_players.clear()
	_order.clear()
	registry_reset.emit()


## 用主机下发的完整快照替换本地列表。
##
## 快照里消失、且新名单中也没有同名人物的玩家视为离开房间：名单替换完成后补发
## player_removed，让非主机端（含观看者）也能弹「玩家离开」提示。同名的记录属于
## 掉线重连换了 peer id，不当作离开。
func replace_from_wire(list: Array) -> void:
	var previous: Array[PlayerProfile] = all()
	var next_players: Dictionary[int, PlayerProfile] = {}
	var next_order: Array[int] = []
	var next_names: Dictionary[String, bool] = {}
	for entry: Variant in list:
		if not (entry is Dictionary):
			continue
		var data: Dictionary = entry
		var profile: PlayerProfile = PlayerProfile.from_wire(data)
		if profile.id == 0:
			continue
		if next_players.has(profile.id):
			continue
		next_players[profile.id] = profile
		next_order.append(profile.id)
		next_names[profile.name] = true
	var removed: Array[PlayerProfile] = []
	for profile: PlayerProfile in previous:
		if next_players.has(profile.id) or next_names.has(profile.name):
			continue
		removed.append(profile)
	_players = next_players
	_order = next_order
	registry_reset.emit()
	# 等名单切换完整后再补发离开事件，避免监听者在半空名单里重建界面。
	for profile: PlayerProfile in removed:
		player_removed.emit(profile.id, profile.name)


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
