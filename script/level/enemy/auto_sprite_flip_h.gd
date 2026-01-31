extends Node

class_name AutoSpriteFlipH

# 支持两种类型的精灵
@export var _sprite2d_path: NodePath = "../Sprite2D"
@export var _animated_sprite2d_path: NodePath = "../AnimatedSprite2D"
@export var _always_face_to_player: bool = false

var _detected_direction_x: int = 0
var _last_position_x: float = 0.0
var sprite
var _flip_h: bool = false


func _ready():
	# 确定使用哪个精灵
	var sprite2d: Sprite2D = get_node_or_null(_sprite2d_path) as Sprite2D
	var animated_sprite2d: AnimatedSprite2D = get_node_or_null(_animated_sprite2d_path) as AnimatedSprite2D
	
	if sprite2d != null:
		sprite = sprite2d
	elif animated_sprite2d != null:
		sprite = animated_sprite2d
	
	if sprite != null:
		_last_position_x = sprite.global_position.x

func _physics_process(delta):
	if sprite == null:
		return

	var current_x: float = sprite.global_position.x
	
	# 永远面朝玩家
	if _always_face_to_player:
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if current_x < player.global_position.x:
			_flip_h = false
		elif current_x > player.global_position.x:
			_flip_h = true
	
		if sprite != null:
			sprite.flip_h = _flip_h
			return
	
	# 检测X方向的变化
	if _last_position_x < current_x:
		_detected_direction_x = 1
	elif _last_position_x > current_x:
		_detected_direction_x = -1
	
	_last_position_x = current_x
	
	# 根据精灵类型设置FlipH	
	if sprite != null:
		sprite.flip_h = (_detected_direction_x == -1)
		
