extends Node

class_name PlatformFallMovement

@export var path_to_move_object: NodePath = ".."
@export var fall_gravity: float = 350.0

var move_object : Node2D
var activated : bool = false
var speed_y : float = 0.0
var gravity : float = 0.0

func _ready() -> void:
	move_object = get_node(path_to_move_object)
	move_object.set_meta("platform_fall_movement", self)

func _physics_process(delta: float) -> void:
	if not activated:
		return
	speed_y += gravity * delta
	if move_object is CharacterBody2D:
		move_object.velocity = Vector2(0.0, speed_y)
		move_object.move_and_slide()
	else:
		move_object.position.y += speed_y * delta

func fall() -> void:
	if activated:
		return
	activated = true
	gravity = fall_gravity
	print("PlatformFallMovement: fall")
