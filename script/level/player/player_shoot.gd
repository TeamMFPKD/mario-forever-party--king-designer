extends Node

signal play_sound_shoot

@export var player_suit : PlayerSuit
@export var player : Node2D
@export var player_animation_sprite : AnimatedSprite2D

@export var fireball_scene : PackedScene
@export var beetroot_scene : PackedScene

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("move_fire"):
		if player_suit.suit != PlayerSuit.SuitType.POWERED:
			return
		match player_suit.power:
			PlayerSuit.PowerupType.FIREBALL:
				if get_tree().get_nodes_in_group("fireball").size() >= 2:
					return
				create_fireball()
				emit_signal("play_sound_shoot")
			PlayerSuit.PowerupType.BEETROOT:
				if get_tree().get_nodes_in_group("beetroot").size() >= 2:
					return
				create_beetroot()
				emit_signal("play_sound_shoot")

func create_fireball() -> void:
	var fireball = fireball_scene.instantiate() as Node2D
	fireball.position = player.position
	fireball.set_meta("fireball_direction", -1 if player_animation_sprite.flip_h else 1)
	print(fireball)
	player.add_sibling(fireball)

func create_beetroot() -> void:
	var beetroot = beetroot_scene.instantiate() as Node2D
	beetroot.position = get_parent().position
	# TODO: 设置 Beetroot 初始方向
	player.add_sibling(beetroot)
