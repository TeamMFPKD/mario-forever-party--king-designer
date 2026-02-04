extends Node

class_name PlayerHurtAndDie

signal play_sound_powerdown
signal play_sound_die

var is_hurting = false
var is_dead = false

@export var invincible_time = 100
var invincible_timer = 0

@export var player_dead_scene: PackedScene = preload("uid://034w35iv6qfh")

@export var player_suit : PlayerSuit
@export var player: Node2D

var level_camera: Camera2D

func _ready() -> void:
	level_camera = get_tree().get_first_node_in_group("level_camera") as Camera2D

func _physics_process(delta: float) -> void:
	#var screen =  ScreenUtils.get_screen_rect(self)
	#if player.position.y > screen.position.y + screen.size.y + 32:
		#_on_player_die()

	if player.position.y > level_camera.limit_bottom + 32:
		_on_player_die()

	if is_hurting:
		invincible_timer += 1
		if invincible_timer >= invincible_time:
			invincible_timer = 0
			is_hurting = false

	if is_dead:
		# TODO: 死亡 => 下一关
		pass

func _on_player_hurt() -> void:
	if is_hurting:
		return
	is_hurting = true
	match player_suit.suit:
		PlayerSuit.SuitType.SMALL:
			_on_player_die()
			return
		PlayerSuit.SuitType.SUPER:
			player_suit.suit = PlayerSuit.SuitType.SMALL
		PlayerSuit.SuitType.POWERED:
			player_suit.suit = PlayerSuit.SuitType.SUPER

func _on_player_die() -> void:
	if is_dead:
		return
	is_dead = true

	var dead = player_dead_scene.instantiate() as Node2D
	dead.position = player.position
	player.add_sibling(dead)

	emit_signal("play_sound_die")
	
	player.visible = false
	player.process_mode = ProcessMode.PROCESS_MODE_DISABLED
