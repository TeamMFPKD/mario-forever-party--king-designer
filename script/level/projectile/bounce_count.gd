extends Node

@export var move_object: CharacterBody2D
@export var bounce_count: int = 5

var bounce_counter: int

func _bounce_count_add() -> void:
	bounce_counter += 1
	if bounce_counter >= bounce_count:
		move_object.collision_layer = 0
		move_object.collision_mask = 0
