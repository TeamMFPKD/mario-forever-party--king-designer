extends Node

signal player_sound_powerdown

var is_hurting = false
var is_dead = false

@export var invincible_time = 100
var invincible_timer = 0

@export var player_dead_scene: PackedScene = preload("uid://034w35iv6qfh")

func _physics_process(delta: float) -> void:
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
	emit_signal("player_sound_powerdown")

func _on_player_die() -> void:
	if is_dead:
		return
	is_dead = true
