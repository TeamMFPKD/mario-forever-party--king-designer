extends Node2D

@export var lerp_speed_x: float = 0.2
@export var lerp_speed_y: float = 0.3
@export var offset_x: float = 24.0
@export var offset_y: float = -4.0

@export var player_sprite: AnimatedSprite2D
@export var player_suit: PlayerSuit

var is_active: bool = false

func _ready() -> void:
	if player_suit:
		if not player_suit.suit_changed.is_connected(_on_suit_changed):
			player_suit.suit_changed.connect(_on_suit_changed)
		_update_active()

func _physics_process(_delta: float) -> void:
	if not is_active:
		return
	
	var facing_dir: int = -1 if _player_flip_h() else 1
	var target_pos := Vector2(-facing_dir * offset_x, offset_y)
	
	position.x = lerpf(position.x, target_pos.x, lerp_speed_x)
	position.y = lerpf(position.y, target_pos.y, lerp_speed_y)
	
	_update_sprite_direction(facing_dir)

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
