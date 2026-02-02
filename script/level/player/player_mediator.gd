extends Node

@export var player : CharacterBody2D
@export var player_movement : Node
@export var player_interaction : Node
@export var player_hurt_and_die : Node
@export var player_suit : Node
@export var player_shoot : Node
@export var player_animation : Node

func _ready() -> void:
	player.set_meta("player_movement", player_movement)
	player.set_meta("player_interaction", player_interaction)
	player.set_meta("player_hurt_and_die", player_hurt_and_die)
	player.set_meta("player_suit", player_suit)
	player.set_meta("player_shoot", player_shoot)
	player.set_meta("player_animation", player_animation)
	