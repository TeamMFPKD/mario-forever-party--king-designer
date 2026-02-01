extends Node

@export var player_suit : PlayerSuit
@export var player : Node2D

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
			PlayerSuit.PowerupType.BEETROOT:
				if get_tree().get_nodes_in_group("beetroot").size() >= 2:
					return
				create_beetroot()

func create_fireball() -> void:
	var fireball = fireball_scene.instance() as Node2D
	fireball.position = get_parent().position
	# TODO: 设置火球初始方向
	player.add_sibling(fireball)

func create_beetroot() -> void:
	var beetroot = beetroot_scene.instance() as Node2D
	beetroot.position = get_parent().position
	# TODO: 设置 Beetroot 初始方向
	player.add_sibling(beetroot)
