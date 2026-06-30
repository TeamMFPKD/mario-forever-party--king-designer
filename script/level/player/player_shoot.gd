extends Node

signal play_sound_shoot

signal play_sound_cloud_platform

@export var player_suit: PlayerSuit
@export var player: Node2D
@export var player_movement: PlayerMovement
@export var player_animation_sprite: AnimatedSprite2D

@export var fireball_scene: PackedScene
@export var beetroot_scene: PackedScene
@export var offset: Vector2 = Vector2(0, -32.0)

@export var cloud_platform_scene: PackedScene
@export var cloud_platform_offset: Vector2 = Vector2(0, -60.0)
@export var cloud_platform_cd: int = 252

var cloud_platform_cd_timer: int = 0


func _physics_process(_delta: float) -> void:
	if player_movement.is_in_transport:
		return
	if is_crouching():
		return
	if player_suit.suit != PlayerSuit.SuitType.POWERED:
		return
		
	if cloud_platform_cd_timer > 0:
		cloud_platform_cd_timer -= 1

	if Input.is_action_just_pressed("move_fire"):
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
			PlayerSuit.PowerupType.CLOUD:
				if cloud_platform_cd_timer > 0:
					return
				create_cloud_platform()
				cloud_platform_cd_timer = cloud_platform_cd
				emit_signal("play_sound_cloud_platform")



func create_fireball() -> void:
	var fireball = fireball_scene.instantiate() as CharacterBody2D
	fireball.position = player.position + offset.rotated(player.rotation)
	fireball.rotation = player.rotation
	fireball.up_direction = player.up_direction
	fireball.set_meta("fireball_direction", -1 if player_animation_sprite.flip_h else 1)
	player.add_sibling(fireball)

func create_beetroot() -> void:
	var beetroot = beetroot_scene.instantiate() as CharacterBody2D
	beetroot.position = player.position + offset.rotated(player.rotation)
	beetroot.rotation = player.rotation
	beetroot.up_direction = player.up_direction
	beetroot.set_meta("beetroot_direction", -1 if player_animation_sprite.flip_h else 1)
	player.add_sibling(beetroot)

func _on_player_hurt() -> void:
	cloud_platform_cd_timer = 0

func create_cloud_platform() -> void:
	var cloud_platform = cloud_platform_scene.instantiate() as Node2D
	cloud_platform.position = player.position + cloud_platform_offset.rotated(player.rotation)
	cloud_platform.rotation = player.rotation
	player.add_sibling(cloud_platform)

func is_crouching() -> bool:
	return player_movement.crouch
	
