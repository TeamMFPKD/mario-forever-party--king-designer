class_name BlockHit
extends Node

signal block_bump
signal block_bump_ended
signal block_break

# 顶砖
@export var bumpable: bool = false
@export var bumpable_one_shot: bool = false
@export var hidden: bool = false:
	set(value):
		hidden = value
		if hidden and is_hard_breakable_block:
			_set_hard_block_meta()

@export var _block_bump_area_2d_scene: PackedScene = preload("uid://8nv6va42xrsg")
@export var sprite: AnimatedSprite2D

@export var sprout_item_scene: PackedScene = null
@export var adv_sprout_item_scene: PackedScene = null

@export var is_hard_breakable_block: bool = true

enum BumpState {
	IDLE,
	BUMPING,
}
var _bump_state: BumpState = BumpState.IDLE
var _bump_state_timer: int = 0
var bumping: bool = false

var player : Node
var player_suit : PlayerSuit

# 碎砖
@export var _breakable: bool = false
@export var _block_fragment_scene: PackedScene = preload("uid://ct006nlnmf8dg")
const FRAMERATE_ORIGIN: float = 60.0
var _fragment_create_position: Array[Vector2] = [
	Vector2(-8.0, -8.0),
	Vector2(8.0, 8.0),
	Vector2(-8.0, 8.0),
	Vector2(8.0, -8.0),
]
var _fragment_velocity_data: Array[Vector2] = [
	Vector2(-3.0, -6.0) * FRAMERATE_ORIGIN,
	Vector2(-2.0, -4.0) * FRAMERATE_ORIGIN,
	Vector2(2.0, -4.0) * FRAMERATE_ORIGIN,
	Vector2(3.0, -6.0) * FRAMERATE_ORIGIN,
]

var parent: StaticBody2D = null

# 隐藏砖设置
@export var _collision_shape_2d: CollisionShape2D
static var _original_collision_shape_2d: Shape2D = null
var _origin_collision_layer: int = 0
#var _hidden_shape: RectangleShape2D = preload("uid://dgpgao4212wvq")

const HIDDEN_LAYER: int = 132


func _ready() -> void:
	parent = get_parent() as StaticBody2D
	_metadata_inject(parent)

	if is_hard_breakable_block and not hidden:
		_set_hard_block_meta()
	
	# 隐藏砖
	_origin_collision_layer = parent.collision_layer
	if _original_collision_shape_2d == null:
		_original_collision_shape_2d = _collision_shape_2d.shape.duplicate()
	if hidden:
		set_hidden()

	var fc = func():
		player = get_tree().get_first_node_in_group("player")
		player_suit = player.get_meta("player_suit") as PlayerSuit
	fc.call_deferred()

func _physics_process(_delta: float) -> void:
	# Hidden Block patch
	if not hidden or not player:
		return
	var player_movement = player.get_meta("player_movement") as PlayerMovement if player.has_meta("player_movement") else null
	if not player_movement:
		return
	if int(round(player_movement.target_gravity)) % 360 != 0:
		parent.collision_layer = 0
	else:
		parent.collision_layer = HIDDEN_LAYER
	


func _metadata_inject(p_parent: Node2D) -> void:
	p_parent.set_meta("interaction_with_block", self)

func _set_hard_block_meta() -> void:
	parent = get_parent()
	parent.set_meta("hard_breakable_block", true)

func on_block_hit(collider: Node2D) -> void:
	if not bumping and is_bumpable(collider):
		bumping = true
		block_bump.emit()
		on_block_bump()
	if is_breakable(collider):
		block_break.emit()
		on_block_break()

func is_hittable(_collider: Node2D) -> bool:
	return true

func is_bumpable(_collider: Node2D) -> bool:
	return bumpable

func is_breakable(_collider: Node2D) -> bool:
	return _breakable

func on_block_bump() -> void:
	if _bump_state != BumpState.IDLE:
		return
	_bump_state = BumpState.BUMPING
	_bump_state_timer = 0
	emit_signal("block_bump")
	if sprite.sprite_frames.has_animation("bumping"):
		sprite.play("bumping")

	# 隐藏砖显现
	if hidden:
		set_visible()

	# 生成物品
	if sprout_item_scene != null and \
	(player_suit.suit == PlayerSuit.SuitType.SMALL or adv_sprout_item_scene == null):
		var sprout_item: Node2D = sprout_item_scene.instantiate()
		sprout_item.position = parent.position
		if has_meta("sprout_down"):
			sprout_item.set_meta("sprout_down", true)
		sprout_item.set_meta("spawned_by_block", true)
		parent.add_sibling(sprout_item)
	if adv_sprout_item_scene != null and player_suit.suit != PlayerSuit.SuitType.SMALL:
		var adv_sprout_item: Node2D = adv_sprout_item_scene.instantiate()
		adv_sprout_item.position = parent.position
		if has_meta("sprout_down"):
			adv_sprout_item.set_meta("sprout_down", true)
		adv_sprout_item.set_meta("spawned_by_block", true)
		parent.add_sibling(adv_sprout_item)
	
	# 顶砖判定生成
	Callable(_create_bump_area).call_deferred()

func _create_bump_area() -> void:
	if parent == null:
		push_error(str(self) + ": Parent is null!")
		return
	
	var block_bump_area_2d: Area2D = _block_bump_area_2d_scene.instantiate()
	block_bump_area_2d.position = parent.position
	parent.add_sibling(block_bump_area_2d)

func on_bumped() -> void:
	_bump_state = BumpState.IDLE
	bumping = false
	if bumpable_one_shot:
		bumpable = false
		if sprite.sprite_frames.has_animation("bumped"):
			sprite.play("bumped")

func on_block_break() -> void:
	if parent == null:
		push_error(str(self) + ": Parent is null!")
		return
	
	for i in range(_fragment_velocity_data.size()):
		var block_fragment: BlockFragment = _block_fragment_scene.instantiate() as BlockFragment
		parent.add_sibling(block_fragment)
		block_fragment.global_position = Vector2(
			parent.global_position.x + _fragment_create_position[i].x,
			parent.global_position.y + _fragment_create_position[i].y
		)
		block_fragment.reset_physics_interpolation()
		block_fragment.speed_x = _fragment_velocity_data[i].x
		block_fragment.speed_y = _fragment_velocity_data[i].y
	
	# 碎砖也触发生成顶砖判定
	Callable(_create_bump_area).call_deferred()
	
	parent.queue_free()

func set_hidden() -> void:
	if parent == null:
		push_error(str(self) + ": Parent is null!")
		return
	sprite.visible = false
	#_collision_shape_2d.position = Vector2.DOWN * 13.0
	parent.collision_layer = HIDDEN_LAYER
	Callable(_apply_hidden_shape).call_deferred()

func _apply_hidden_shape() -> void:
	#_collision_shape_2d.shape = _hidden_shape
	_collision_shape_2d.one_way_collision = true

func set_visible() -> void:
	if parent == null:
		push_error(str(self) + ": Parent is null!")
		return
	hidden = false
	sprite.visible = true
	parent.collision_layer = _origin_collision_layer
	Callable(_apply_visible_shape).call_deferred()
	_collision_shape_2d.position = Vector2.ZERO

func _apply_visible_shape() -> void:
	#_collision_shape_2d.shape = _original_collision_shape_2d
	_collision_shape_2d.one_way_collision = false
