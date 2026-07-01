extends Node2D

@export var lerp_speed_x: float = 0.2
@export var lerp_speed_y: float = 0.3
@export var offset_x: float = 24.0
@export var offset_y: float = -4.0

@export var player_sprite: AnimatedSprite2D
@export var player_suit: PlayerSuit
@export var player_shoot: Node

var is_active: bool = false
var _was_platform_exists: bool = false
var _last_platform_global_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	if player_suit:
		if not player_suit.suit_changed.is_connected(_on_suit_changed):
			player_suit.suit_changed.connect(_on_suit_changed)
		_update_active()
	_setup_cooldown_animation()

func _setup_cooldown_animation() -> void:
	var ani = get_node_or_null("AnimatedSprite2D")
	if not ani or not ani.sprite_frames:
		return
	if ani.sprite_frames.has_animation("cooldown"):
		return
	var frames = ani.sprite_frames
	frames.add_animation("cooldown")
	frames.set_animation_speed("cooldown", 2.5)
	frames.set_animation_loop("cooldown", true)
	for i in range(frames.get_frame_count("default")):
		frames.add_frame("cooldown", frames.get_frame_texture("default", i), frames.get_frame_duration("default", i))

func _physics_process(_delta: float) -> void:
	if not is_active:
		return
	
	var ani = get_node_or_null("AnimatedSprite2D")
	var platforms = get_tree().get_nodes_in_group("cloud_platform_player")
	var platform_exists = platforms.size() > 0
	var is_cd = _is_cooldown()
	
	if platform_exists:
		if platforms[0]:
			_last_platform_global_pos = platforms[0].global_position
		if ani:
			ani.visible = false
		_was_platform_exists = true
		return
	
	if _was_platform_exists and not platform_exists:
		global_position = _last_platform_global_pos
		_was_platform_exists = false
	
	if ani:
		ani.visible = true
	
	var target_scale := Vector2(0.5, 0.5) if is_cd else Vector2.ONE
	scale = scale.lerp(target_scale, 0.15)
	
	if is_cd and ani and ani.sprite_frames and ani.sprite_frames.has_animation("cooldown"):
		ani.play("cooldown")
	elif ani:
		ani.play("default")
	
	var facing_dir: int = -1 if _player_flip_h() else 1
	var target_pos := Vector2(-facing_dir * offset_x, offset_y)
	
	position.x = lerpf(position.x, target_pos.x, lerp_speed_x)
	position.y = lerpf(position.y, target_pos.y, lerp_speed_y)
	
	_update_sprite_direction(facing_dir)

func _is_cooldown() -> bool:
	if not is_instance_valid(player_shoot):
		return false
	return player_shoot.cloud_platform_cd_timer > 0

func _player_flip_h() -> bool:
	if is_instance_valid(player_sprite):
		return player_sprite.flip_h
	return false

func _update_sprite_direction(facing_dir: int) -> void:
	var ani = get_node_or_null("AnimatedSprite2D")
	if ani:
		ani.flip_h = facing_dir == -1

func _on_suit_changed() -> void:
	_update_active()

func _update_active() -> void:
	var active = player_suit.suit == PlayerSuit.SuitType.POWERED and player_suit.power == PlayerSuit.PowerupType.CLOUD
	if active != is_active:
		is_active = active
		for child in get_children():
			if child is CanvasItem:
				child.visible = active
		if is_active:
			position = Vector2.ZERO
			_was_platform_exists = false
