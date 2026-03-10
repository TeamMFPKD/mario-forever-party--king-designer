extends Node

class_name PlayerHurtAndDie

signal play_sound_powerdown
signal play_sound_die
signal player_suicided

var is_hurting = false
var is_dead = false

@export var invincible_time = 100
var invincible_timer = 0

@export var player_dead_scene: PackedScene = preload("uid://034w35iv6qfh")

@export var player_suit : PlayerSuit
@export var player: Node2D

var level_camera: Camera2D

var invincible : bool
var invincible_starman : bool

var game_timer : Timer

func _ready() -> void:
	level_camera = get_tree().get_first_node_in_group("level_camera") as Camera2D
	game_timer = get_tree().get_first_node_in_group("game_timer") as Timer
	if game_timer:
		game_timer.timeout.connect(_on_player_die)

func _physics_process(_delta: float) -> void:
	#var screen =  ScreenUtils.get_screen_rect(self)
	#if player.position.y > screen.position.y + screen.size.y + 32:
		#_on_player_die()

	# Suicide
	if Input.is_action_just_pressed("restart"):
		emit_signal("player_suicided")
		_on_player_die()

	# Update invincible
	update_invincible()

	if player.position.y > level_camera.limit_bottom + 32:
		_on_player_die()

	if is_hurting:
		invincible_timer += 1
		if invincible_timer >= invincible_time:
			invincible_timer = 0
			is_hurting = false

	if is_dead:
		# 死亡 => 返回 Edit / 下一关
		# 见玩家尸体
		pass

func _on_player_hurt() -> void:
	if invincible:
		return
	is_hurting = true
	update_invincible()
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

	if is_inside_tree():
		emit_signal("play_sound_die")
	
	player.visible = false
	player.process_mode = ProcessMode.PROCESS_MODE_DISABLED

func _on_starman_start() -> void:
	invincible_starman = true
	update_invincible()

func _on_starman_end() -> void:
	invincible_starman = false

func update_invincible() -> void:
	invincible = invincible_starman or is_hurting
