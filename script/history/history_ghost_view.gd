class_name HistoryGhostView
extends Node2D

@warning_ignore_start("unsafe_cast", "unsafe_call_argument", "unsafe_method_access", "unsafe_property_access", "integer_division")

## 历史记录里的联机幽灵回放。
##
## 录制在常驻的 GhostCacheService（MPManager.ghosts）里完成，因此玩家分散在
## 不同关卡时也能缓存彼此在各自关卡的轨迹。
## 回放：HISTORY_PLAY 顺序播放，HISTORY_EDIT 循环播放；只显示非本地玩家，
## 纯视觉、不参与碰撞，也不写入关卡数据。
##
## 采样字段与 MpAniSpriteManager 的 send_ani_sprite_data 一致：
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

var _replaying: bool = false
var _loop: bool = false
var _level_path: String = ""
var _elapsed: float = 0.0
var _duration: float = 0.0

var _play_players: Array = []
var _sprites: Array[AnimatedSprite2D] = []
var _cursors: Array[int] = []
var _visibility: Array[bool] = []
var _last_positions: Array[Vector2] = []


func _ready() -> void:
	var mode: GameMode = GameModeSingleton
	match mode.game_mode:
		GameMode.GameModeType.HISTORY_PLAY:
			_setup_replay(false)
		GameMode.GameModeType.HISTORY_EDIT:
			_setup_replay(true)
		_:
			set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _replaying:
		return
	_elapsed += delta
	if _duration > 0.0:
		if _loop:
			_elapsed = fmod(_elapsed, _duration)
		else:
			_elapsed = minf(_elapsed, _duration)
	_update_sprites()


# ---------------------------------------------------------------------------
# 回放
# ---------------------------------------------------------------------------

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
