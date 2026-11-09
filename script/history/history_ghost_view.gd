class_name HistoryGhostView
extends Node2D

@warning_ignore_start("unsafe_cast", "unsafe_call_argument", "unsafe_method_access", "unsafe_property_access", "integer_division")

## 历史记录里的联机幽灵。
##
## 录制：MultiplayerAniSpriteManager 每 12 Hz 发送/接收玩家状态时调用
## record_local() / record_remote()，离开关卡时写入 user://ghosts/。
## 回放：HISTORY_PLAY 顺序播放，HISTORY_EDIT 循环播放；只显示非本地玩家，
## 纯视觉、不参与碰撞，也不写入关卡数据。
##
## 采样字段与 MultiplayerAniSpriteManager.send_ani_sprite_data 一致：
##   [t, x, y, suit, power, anim_index, frame, flip_h, scale_x, scale_y, rotation, dead]

@export var shadow_scene: PackedScene
@export var player_dead_spritesframe: SpriteFrames
@export var player_small_spritesframe: SpriteFrames
@export var player_super_spritesframe: SpriteFrames
@export var player_fireball_spritesframe: SpriteFrames
@export var player_beetroot_spritesframe: SpriteFrames
@export var player_lui_spritesframe: SpriteFrames
@export var player_big_spritesframe: SpriteFrames
@export var player_bee_spritesframe: SpriteFrames
@export var player_cloud_spritesframe: SpriteFrames

## 在阴影贴图（默认 0.25 透明）基础上再乘的透明度。
@export_range(0.0, 1.0, 0.01) var ghost_alpha: float = 1.0

const MAX_PLAYERS: int = 8
const MAX_SAMPLES_PER_PLAYER: int = 12000
const SETTINGS_SECTION: String = "options"
const SETTINGS_KEY: String = "history_ghost_enabled"

## 单帧位移超过该距离视为瞬移（死亡重生、换关、回放循环回绕等），
## 重置物理插值，避免幽灵从旧位置拖一条线过来。
const TELEPORT_DISTANCE: float = 32.0
const TELEPORT_DISTANCE_SQUARED: float = TELEPORT_DISTANCE * TELEPORT_DISTANCE

const SAMPLE_T: int = 0
const SAMPLE_X: int = 1
const SAMPLE_Y: int = 2
const SAMPLE_SUIT: int = 3
const SAMPLE_POWER: int = 4
const SAMPLE_ANIM: int = 5
const SAMPLE_FRAME: int = 6
const SAMPLE_FLIP: int = 7
const SAMPLE_SCALE_X: int = 8
const SAMPLE_SCALE_Y: int = 9
const SAMPLE_ROTATION: int = 10
const SAMPLE_DEAD: int = 11

var _recording: bool = false
var _replaying: bool = false
var _loop: bool = false
var _level_path: String = ""
var _elapsed: float = 0.0
var _record_clock: float = 0.0
var _duration: float = 0.0
var _local_id: int = 0

var _record_players: Dictionary = {}

var _play_players: Array = []
var _sprites: Array[AnimatedSprite2D] = []
var _cursors: Array[int] = []
var _visibility: Array[bool] = []
var _last_positions: Array[Vector2] = []


func _ready() -> void:
	var mode: GameMode = GameModeSingleton
	match mode.game_mode:
		GameMode.GameModeType.PLAY:
			call_deferred("_setup_recording")
		GameMode.GameModeType.HISTORY_PLAY:
			_setup_replay(false)
		GameMode.GameModeType.HISTORY_EDIT:
			_setup_replay(true)
		_:
			set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _recording:
		_record_clock += delta
		return
	if not _replaying:
		return
	_elapsed += delta
	if _duration > 0.0:
		if _loop:
			_elapsed = fmod(_elapsed, _duration)
		else:
			_elapsed = minf(_elapsed, _duration)
	_update_sprites()


func _exit_tree() -> void:
	if not _recording:
		return
	var has_remote: bool = false
	var players: Array = []
	for value: Variant in _record_players.values():
		var entry: Dictionary = value
		if not bool(entry.get("local", false)):
			has_remote = true
		players.append(entry)
	# 单人房间只录到自己，history 回放又隐藏自己，没有保存价值。
	if not has_remote or players.is_empty():
		return
	HistoryGhostCache.save_ghost(_level_path, _record_clock, players)


# ---------------------------------------------------------------------------
# 录制（由 MultiplayerAniSpriteManager 调用）
# ---------------------------------------------------------------------------

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
	if not _recording:
		return
	var player_name: String = str(MPManager.player_name)
	if player_name.is_empty():
		player_name = str(MPManager.player.name)
	_record_sample(
		_local_id, player_name, true,
		suit, power, animation, frame, flip_h, is_dead,
		position, sprite_scale, rotation
	)


func record_remote(
	player_id: int,
	position: Vector2,
	suit: PlayerSuit.SuitType,
	power: PlayerSuit.PowerupType,
	animation: StringName,
	frame: int,
	flip_h: bool,
	is_dead: bool,
	sprite_scale: Vector2,
	rotation: float
) -> void:
	if not _recording:
		return
	var player_name: String = ""
	var profile: PlayerProfile = MPManager.registry.get_player(player_id)
	if profile != null:
		player_name = profile.name
	if player_name.is_empty():
		player_name = "Player %d" % player_id
	_record_sample(
		player_id, player_name, false,
		suit, power, animation, frame, flip_h, is_dead,
		position, sprite_scale, rotation
	)


func _record_sample(
	player_id: int,
	player_name: String,
	is_local: bool,
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
	var entry: Dictionary = _record_players.get(player_id, {})
	if entry.is_empty():
		if _record_players.size() >= MAX_PLAYERS:
			return
		entry = {
			"id": player_id,
			"name": player_name,
			"local": is_local,
			"animations": [],
			"samples": [],
		}
		_record_players[player_id] = entry
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
		snappedf(_record_clock, 0.01),
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


# ---------------------------------------------------------------------------
# 回放
# ---------------------------------------------------------------------------

func _setup_recording() -> void:
	if shadow_scene == null:
		return
	var level_path: String = _current_play_level_path()
	if level_path.is_empty():
		set_physics_process(false)
		return
	_level_path = level_path
	_local_id = int(MPManager.player.id)
	_record_players.clear()
	_record_clock = 0.0
	_recording = true


func _setup_replay(loop_mode: bool) -> void:
	if shadow_scene == null or not _is_enabled_in_config():
		set_physics_process(false)
		return
	var level_path: String = _history_level_path()
	if level_path.is_empty():
		set_physics_process(false)
		return
	var data: Dictionary = HistoryGhostCache.load_ghost(level_path)
	if data.is_empty():
		set_physics_process(false)
		return
	_level_path = level_path
	_duration = float(data.get("duration", 0.0))
	_loop = loop_mode
	var players: Array = data.get("players", [])
	for value: Variant in players:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		if bool(entry.get("local", false)):
			continue
		var samples: Variant = entry.get("samples", [])
		if not samples is Array:
			continue
		var sample_array: Array = samples
		if sample_array.is_empty():
			continue
		var sprite: AnimatedSprite2D = _create_sprite(entry, sample_array)
		if sprite == null:
			continue
		_play_players.append(entry)
		_sprites.append(sprite)
		_cursors.append(0)
		_visibility.append(false)
		_last_positions.append(Vector2.ZERO)
	if _sprites.is_empty():
		set_physics_process(false)
		return
	_replaying = true
	Log.i("HistoryGhostView", ["回放幽灵：", level_path, " 玩家数 ", str(_sprites.size())])


func _create_sprite(entry: Dictionary, samples: Array) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = shadow_scene.instantiate() as AnimatedSprite2D
	if sprite == null:
		return null
	sprite.visible = false
	sprite.self_modulate.a *= ghost_alpha
	var label: Label = sprite.get_node_or_null("%PlayerNameLabel") as Label
	if label != null:
		label.text = str(entry.get("name", ""))
	add_child(sprite)
	var first: Array = samples[0]
	_apply_sample(sprite, entry, first)
	return sprite


func _update_sprites() -> void:
	for index: int in range(_sprites.size()):
		var entry: Dictionary = _play_players[index]
		var samples: Array = entry["samples"]
		var sprite: AnimatedSprite2D = _sprites[index]
		var first_sample: Array = samples[0]
		if _elapsed < float(first_sample[SAMPLE_T]):
			_set_visible(index, false)
			continue
		var cursor: int = _cursors[index]
		if cursor >= samples.size() or _elapsed < float(samples[cursor][SAMPLE_T]):
			cursor = 0
		while cursor + 1 < samples.size() \
				and float(samples[cursor + 1][SAMPLE_T]) <= _elapsed:
			cursor += 1
		_cursors[index] = cursor
		var current: Array = samples[cursor]
		var next: Array = current
		var blend: float = 0.0
		if cursor + 1 < samples.size():
			next = samples[cursor + 1]
			var current_t: float = float(current[SAMPLE_T])
			var next_t: float = float(next[SAMPLE_T])
			if next_t > current_t:
				blend = clampf((_elapsed - current_t) / (next_t - current_t), 0.0, 1.0)
		var position: Vector2 = Vector2(
			lerpf(float(current[SAMPLE_X]), float(next[SAMPLE_X]), blend),
			lerpf(float(current[SAMPLE_Y]), float(next[SAMPLE_Y]), blend)
		)
		var previous_position: Vector2 = _last_positions[index]
		var was_visible: bool = _visibility[index]
		sprite.global_position = position
		_last_positions[index] = position
		sprite.scale = Vector2(
			lerpf(float(current[SAMPLE_SCALE_X]), float(next[SAMPLE_SCALE_X]), blend),
			lerpf(float(current[SAMPLE_SCALE_Y]), float(next[SAMPLE_SCALE_Y]), blend)
		)
		sprite.rotation = lerp_angle(float(current[SAMPLE_ROTATION]), float(next[SAMPLE_ROTATION]), blend)
		_apply_sample(sprite, entry, current)
		_set_visible(index, true)
		if was_visible and previous_position.distance_squared_to(position) >= TELEPORT_DISTANCE_SQUARED:
			sprite.reset_physics_interpolation()


func _apply_sample(sprite: AnimatedSprite2D, entry: Dictionary, sample: Array) -> void:
	var dead: bool = bool(sample[SAMPLE_DEAD])
	var frames: SpriteFrames = _frames_for(
		int(sample[SAMPLE_SUIT]), int(sample[SAMPLE_POWER]), dead
	)
	if frames != null and sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
		var names: PackedStringArray = frames.get_animation_names()
		if names.size() > 0:
			sprite.animation = StringName(names[0])
	var animations: Array = entry.get("animations", [])
	var anim_index: int = int(sample[SAMPLE_ANIM])
	if anim_index >= 0 and anim_index < animations.size():
		var anim_name: StringName = StringName(str(animations[anim_index]))
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
			sprite.animation = anim_name
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		var frame_count: int = sprite.sprite_frames.get_frame_count(sprite.animation)
		if frame_count > 0:
			sprite.frame = clampi(int(sample[SAMPLE_FRAME]), 0, frame_count - 1)
	sprite.flip_h = bool(sample[SAMPLE_FLIP])


func _set_visible(index: int, value: bool) -> void:
	if _visibility[index] == value:
		return
	_visibility[index] = value
	_sprites[index].visible = value
	if value:
		_sprites[index].reset_physics_interpolation()
		_last_positions[index] = _sprites[index].global_position


func _frames_for(suit: int, power: int, dead: bool) -> SpriteFrames:
	if dead:
		return player_dead_spritesframe
	if suit == int(PlayerSuit.SuitType.SMALL):
		return player_small_spritesframe
	if suit == int(PlayerSuit.SuitType.SUPER):
		return player_super_spritesframe
	match power:
		PlayerSuit.PowerupType.FIREBALL:
			return player_fireball_spritesframe
		PlayerSuit.PowerupType.BEETROOT:
			return player_beetroot_spritesframe
		PlayerSuit.PowerupType.LUI:
			return player_lui_spritesframe
		PlayerSuit.PowerupType.BIG:
			return player_big_spritesframe
		PlayerSuit.PowerupType.BEE:
			return player_bee_spritesframe
		PlayerSuit.PowerupType.CLOUD:
			return player_cloud_spritesframe
	return player_small_spritesframe


# ---------------------------------------------------------------------------
# 路径与设置
# ---------------------------------------------------------------------------

func _current_play_level_path() -> String:
	var levels: Array[String] = MPManager.random_levels
	if levels.is_empty():
		return ""
	var index: int = clampi(MPManager.current_level_count, 0, levels.size() - 1)
	return levels[index]


func _history_level_path() -> String:
	var setter: Node = get_node_or_null("/root/LevelPathSet")
	if setter == null or not setter.has_meta("level_path_name"):
		return ""
	return str(setter.get_meta("level_path_name"))


func _is_enabled_in_config() -> bool:
	var value: Variant = GameConfig.config.get_value(SETTINGS_SECTION, SETTINGS_KEY, true)
	if value is bool:
		return value
	return true
