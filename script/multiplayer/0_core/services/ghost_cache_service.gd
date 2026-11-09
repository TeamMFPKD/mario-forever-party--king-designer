class_name GhostCacheService
extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument", "unsafe_method_access", "unsafe_property_access")

## 联机幽灵缓存服务（常驻 MPManager）。
##
## 与场景内的 MultiplayerAniSpriteManager 分工：
## - 本服务通过 RPC 接收所有玩家的 12 Hz 状态，**不要求双方在同一关卡**，
##   按“玩家所在关卡”分别录制，因此玩家分散在关卡 1 / 关卡 2 时也能互相缓存；
## - 同一关卡（本地当前关）的数据再转发给场景管理器做实时幽灵显示；
## - 写盘时机：本地关卡切换、离开 PLAY 阶段、退出游戏。
##
## 每个玩家进入某关时从 0 开始计时（entry.start_time），回放时按各自在该关的
## 时间轴播放；玩家重新进入同一关会重置该关的旧录制（以最后一次为准）。

const MAX_PLAYERS: int = 8
const MAX_SAMPLES_PER_PLAYER: int = 12000

var _manager: MultiplayerManager
var _clock: float = 0.0
var _last_level_count: int = -1
var _was_playing: bool = false
## level_path -> { player_id -> entry }
var _levels: Dictionary = {}
## player_id -> 最近一次录制时所在关卡索引（用于检测换关/重进）
var _last_level_of_player: Dictionary = {}
var _attached_manager: WeakRef


func setup(manager: MultiplayerManager) -> void:
	_manager = manager


func attach_manager(manager: Node) -> void:
	_attached_manager = weakref(manager)


func detach_manager(manager: Node) -> void:
	if _attached_manager == null:
		return
	if _attached_manager.get_ref() == manager:
		_attached_manager = null


func _physics_process(delta: float) -> void:
	if _manager == null:
		return
	var playing: bool = _is_playing()
	if playing:
		_clock += delta
	var level_count: int = _manager.current_level_count
	if level_count != _last_level_count:
		_last_level_count = level_count
		flush_all()
	if _was_playing and not playing:
		flush_all()
		_levels.clear()
		_last_level_of_player.clear()
	_was_playing = playing


func _exit_tree() -> void:
	flush_all()


# ---------------------------------------------------------------------------
# 录制入口
# ---------------------------------------------------------------------------

## 本地玩家 12 Hz 采样（由场景内 MpAniSpriteManager 调用）。
func record_local(
	suit: PlayerSuit.SuitType,
	power: PlayerSuit.PowerupType,
	animation: StringName,
	frame: int,
	flip_h: bool,
	is_dead: bool,
	position: Vector2,
	sprite_scale: Vector2,
	rotation: float
) -> void:
	if not _is_playing() or _manager.players.size() <= 1:
		return
	var level_index: int = _manager.current_level_count
	var level_path: String = _level_path_for_index(level_index)
	if level_path.is_empty():
		return
	var entry: Dictionary = _prepare_entry(level_index, level_path, _manager.player.id, true)
	_append_sample(
		entry, suit, power, animation, frame, flip_h, is_dead,
		position, sprite_scale, rotation
	)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func send_ani_sprite_data(
	player_id: int,
	current_level: int,
	ani_pos: Vector2,
	suit: PlayerSuit.SuitType,
	power: PlayerSuit.PowerupType,
	animation: StringName,
	frame: int,
	flip_h: bool,
	is_dead: bool,
	sprite_scale: Vector2,
	rotation: float
) -> void:
	if _manager == null or not _is_playing():
		return
	if not _manager.registry.has_player(player_id):
		return
	var level_path: String = _level_path_for_index(current_level)
	if level_path.is_empty():
		return
	var entry: Dictionary = _prepare_entry(current_level, level_path, player_id, false)
	_append_sample(
		entry, suit, power, animation, frame, flip_h, is_dead,
		ani_pos, sprite_scale, rotation
	)
	# 实时幽灵仍只显示同关玩家：跨关坐标在当前关没有意义。
	if current_level == _manager.current_level_count:
		_forward_to_scene(
			player_id, ani_pos, suit, power, animation, frame, flip_h,
			is_dead, sprite_scale, rotation
		)


func _forward_to_scene(
	player_id: int,
	ani_pos: Vector2,
	suit: PlayerSuit.SuitType,
	power: PlayerSuit.PowerupType,
	animation: StringName,
	frame: int,
	flip_h: bool,
	is_dead: bool,
	sprite_scale: Vector2,
	rotation: float
) -> void:
	if _attached_manager == null:
		return
	var manager: MpAniSpriteManager = _attached_manager.get_ref() as MpAniSpriteManager
	if manager == null or not is_instance_valid(manager):
		return
	manager.apply_remote_state(
		player_id, ani_pos, suit, power, animation, frame, flip_h,
		is_dead, sprite_scale, rotation
	)


# ---------------------------------------------------------------------------
# 数据维护
# ---------------------------------------------------------------------------

func _prepare_entry(
	level_index: int,
	level_path: String,
	player_id: int,
	is_local: bool
) -> Dictionary:
	var previous_index: int = int(_last_level_of_player.get(player_id, -1))
	if previous_index != level_index:
		_last_level_of_player[player_id] = level_index
		_reset_entry(level_path, player_id)
	if not _levels.has(level_path):
		_levels[level_path] = {}
	var level_players: Dictionary = _levels[level_path]
	if not level_players.has(player_id):
		if level_players.size() >= MAX_PLAYERS:
			return {}
		var entry: Dictionary = {
			"id": player_id,
			"name": _player_name(player_id, is_local),
			"local": is_local,
			"animations": [],
			"samples": [],
			"start_time": _clock,
		}
		level_players[player_id] = entry
	var entry: Dictionary = level_players[player_id]
	return entry


func _reset_entry(level_path: String, player_id: int) -> void:
	if not _levels.has(level_path):
		return
	var level_players: Dictionary = _levels[level_path]
	if not level_players.has(player_id):
		return
	level_players.erase(player_id)
	_levels[level_path] = level_players


func _append_sample(
	entry: Dictionary,
	suit: PlayerSuit.SuitType,
	power: PlayerSuit.PowerupType,
	animation: StringName,
	frame: int,
	flip_h: bool,
	is_dead: bool,
	position: Vector2,
	sprite_scale: Vector2,
	rotation: float
) -> void:
	if entry.is_empty():
		return
	var samples: Array = entry["samples"]
	if samples.size() >= MAX_SAMPLES_PER_PLAYER:
		return
	var animations: Array = entry["animations"]
	var anim_name: String = String(animation)
	var anim_index: int = animations.find(anim_name)
	if anim_index < 0:
		if animations.size() >= 64:
			anim_index = 0
		else:
			animations.append(anim_name)
			anim_index = animations.size() - 1
	samples.append([
		snappedf(_clock - float(entry["start_time"]), 0.01),
		snappedf(position.x, 0.1),
		snappedf(position.y, 0.1),
		int(suit),
		int(power),
		anim_index,
		frame,
		flip_h,
		snappedf(sprite_scale.x, 0.001),
		snappedf(sprite_scale.y, 0.001),
		snappedf(rotation, 0.001),
		is_dead,
	])


## 把已录制的所有关卡写入 user://ghosts/。没有远端玩家的关卡不写。
func flush_all() -> void:
	for key: Variant in _levels.keys():
		var level_path: String = str(key)
		var level_players: Dictionary = _levels[key]
		var players: Array = []
		var has_remote: bool = false
		var duration: float = 0.0
		for value: Variant in level_players.values():
			var entry: Dictionary = value
			var samples: Array = entry["samples"]
			if samples.is_empty():
				continue
			if not bool(entry.get("local", false)):
				has_remote = true
			var last: Array = samples[samples.size() - 1]
			duration = maxf(duration, float(last[0]))
			players.append({
				"id": entry["id"],
				"name": entry["name"],
				"local": entry["local"],
				"animations": entry["animations"],
				"samples": samples,
			})
		if not has_remote or players.is_empty():
			continue
		HistoryGhostCache.save_ghost(level_path, duration, players)


func _level_path_for_index(index: int) -> String:
	var levels: Array[String] = _manager.random_levels
	if index < 0 or index >= levels.size():
		return ""
	return levels[index]


func _player_name(player_id: int, is_local: bool) -> String:
	if is_local:
		var local_name: String = str(_manager.player_name)
		if local_name.is_empty():
			local_name = str(_manager.player.name)
		return local_name
	var profile: PlayerProfile = _manager.registry.get_player(player_id)
	if profile != null:
		return profile.name
	return "Player %d" % player_id


func _is_playing() -> bool:
	return _manager.phase == RoomPhase.Phase.PLAY
