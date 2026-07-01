extends Node2D

@export var player_suit: PlayerSuit
@export var player_movement: PlayerMovement

var _bar_sprite: Sprite2D
var _progress_sprite: Sprite2D

func _ready() -> void:
	_bar_sprite = get_node_or_null("Bar")
	_progress_sprite = get_node_or_null("Progress")
	if _progress_sprite and _progress_sprite.texture:
		_progress_sprite.position.x = -_progress_sprite.texture.get_width() / 2.0
	if player_suit:
		if not player_suit.suit_changed.is_connected(_on_suit_changed):
			player_suit.suit_changed.connect(_on_suit_changed)
	_update_active()

func _process(_delta: float) -> void:
	if not _is_active():
		return
	_update()

func _update_active() -> void:
	var active = player_suit.suit == PlayerSuit.SuitType.POWERED and player_suit.power == PlayerSuit.PowerupType.BEE
	visible = active

func _is_active() -> bool:
	if not is_instance_valid(player_suit):
		return false
	return player_suit.suit == PlayerSuit.SuitType.POWERED and player_suit.power == PlayerSuit.PowerupType.BEE

func _on_suit_changed() -> void:
	_update_active()

func _update() -> void:
	if not is_instance_valid(player_movement):
		return

	var ratio = 1.0 - (player_movement.bee_fly_timer / maxf(player_movement.bee_fly_time_max, 0.001))
	ratio = clampf(ratio, 0.0, 1.0)

	if _bar_sprite:
		_bar_sprite.frame = clampi(floori((1.0 - ratio) * 4.0), 0, 3)

	if _progress_sprite:
		_progress_sprite.scale.x = ratio
		_progress_sprite.modulate = Color(0, ratio, 1.0 - ratio, 1.0)
