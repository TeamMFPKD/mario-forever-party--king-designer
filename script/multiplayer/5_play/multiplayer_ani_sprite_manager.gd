extends Node2D

class_name MpAniSpriteManager

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 远端玩家动画同步（游玩场景内自包含）。
##
## 发送频率从“每个物理帧”降到 12 Hz；RPC 走 GhostCacheService
## （常驻 MPManager，跨关也能录制幽灵）。套装贴图配置也从
## MultiplayerManager 搬到这里，网络门面不再持有表现资源。

@export var mp_ani_shadow_scene: PackedScene

@export var player_dead_spritesframe: SpriteFrames
@export var player_small_spritesframe: SpriteFrames
@export var player_super_spritesframe: SpriteFrames
@export var player_fireball_spritesframe: SpriteFrames
@export var player_beetroot_spritesframe: SpriteFrames
@export var player_lui_spritesframe: SpriteFrames
@export var player_big_spritesframe: SpriteFrames
@export var player_bee_spritesframe: SpriteFrames
@export var player_cloud_spritesframe: SpriteFrames

## 12 Hz 足够表现，且比原来的 60 Hz 省 80% 流量。
const SEND_INTERVAL: float = 1.0 / 12.0

var anis: Array[AnimatedSprite2D] = []
var local_ani: AnimatedSprite2D
var player_suit: PlayerSuit
var player_hurt_and_die: PlayerHurtAndDie

var _send_accum: float = 0.0
var _no_player_print_limit: int = 0


func _ready() -> void:
	var game_mode_manager: GameMode = GameModeSingleton
	if game_mode_manager.game_mode != GameMode.GameModeType.PLAY:
		return
	if MPManager.ghosts != null:
		MPManager.ghosts.attach_manager(self)
	var multiplayer_count: int = MPManager.players.size() - 1
	for _index: int in range(multiplayer_count):
		var ani: AnimatedSprite2D = mp_ani_shadow_scene.instantiate() as AnimatedSprite2D
		ani.position = Vector2(-999999, -999999)
		anis.append(ani)
		add_child(ani)


func _physics_process(delta: float) -> void:
	var game_mode_manager: GameMode = GameModeSingleton
	if game_mode_manager.game_mode != GameMode.GameModeType.PLAY:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		if _no_player_print_limit < 10:
			_no_player_print_limit += 1
			Log.i("MultiplayerAniSpriteManager", "No player node found")
		return
	if not local_ani:
		local_ani = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
		if not local_ani:
			return
	if not player_suit:
		player_suit = player.get_meta("player_suit")
		if not player_suit:
			return
	if not player_hurt_and_die:
		player_hurt_and_die = player.get_meta("player_hurt_and_die")
		if not player_hurt_and_die:
			return

	_send_accum += delta
	if _send_accum < SEND_INTERVAL:
		return
	_send_accum = 0.0

	if MPManager.ghosts != null:
		MPManager.ghosts.record_local(
			player_suit.suit,
			player_suit.power,
			local_ani.animation,
			local_ani.frame,
			local_ani.flip_h,
			player_hurt_and_die.is_dead,
			local_ani.global_position,
			local_ani.scale,
			local_ani.global_rotation
		)

	if MPManager.ghosts != null:
		MPManager.ghosts.send_ani_sprite_data.rpc(
			MPManager.player.id,
			MPManager.current_level_count,
			local_ani.global_position,
			player_suit.suit,
			player_suit.power,
			local_ani.animation,
			local_ani.frame,
			local_ani.flip_h,
			player_hurt_and_die.is_dead,
			local_ani.scale,
			local_ani.global_rotation
		)


func _exit_tree() -> void:
	if is_instance_valid(MPManager) and MPManager.ghosts != null:
		MPManager.ghosts.detach_manager(self)


## 由 GhostCacheService 在“发送端与本机在同一关卡”时调用。
func apply_remote_state(
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
	var target: AnimatedSprite2D = null
	for ani: AnimatedSprite2D in anis:
		if ani.has_meta("player_id") and int(ani.get_meta("player_id")) == player_id:
			target = ani
			break
	if target == null:
		for ani: AnimatedSprite2D in anis:
			if not ani.has_meta("player_id"):
				ani.set_meta("player_id", player_id)
				target = ani
				break
	if target == null:
		return

	target.global_position = ani_pos
	target.scale = sprite_scale
	target.rotation = rotation
	var why_control_hasnt_global_rotation: Node2D = target.get_node("%WhyControlHasntGlobalRotation")
	why_control_hasnt_global_rotation.global_rotation = 0.0
	var label: Label = target.get_node("%PlayerNameLabel")
	var profile: PlayerProfile = MPManager.registry.get_player(player_id)
	if profile != null:
		label.text = profile.name

	if is_dead:
		target.sprite_frames = player_dead_spritesframe
		target.position += Vector2(0.0, 20.0).rotated(rotation)
		return

	match suit:
		PlayerSuit.SuitType.SMALL:
			target.sprite_frames = player_small_spritesframe
		PlayerSuit.SuitType.SUPER:
			target.sprite_frames = player_super_spritesframe
		PlayerSuit.SuitType.POWERED:
			match power:
				PlayerSuit.PowerupType.FIREBALL:
					target.sprite_frames = player_fireball_spritesframe
				PlayerSuit.PowerupType.BEETROOT:
					target.sprite_frames = player_beetroot_spritesframe
				PlayerSuit.PowerupType.LUI:
					target.sprite_frames = player_lui_spritesframe
				PlayerSuit.PowerupType.BIG:
					target.sprite_frames = player_big_spritesframe
				PlayerSuit.PowerupType.BEE:
					target.sprite_frames = player_bee_spritesframe
				PlayerSuit.PowerupType.CLOUD:
					target.sprite_frames = player_cloud_spritesframe
	target.animation = animation
	target.frame = frame
	target.flip_h = flip_h
