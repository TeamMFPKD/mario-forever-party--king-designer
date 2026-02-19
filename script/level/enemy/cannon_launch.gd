extends Node

signal play_sound_launch

@export var path_to_cannon : NodePath = ".."
@export var bullet_bill_scene : PackedScene = preload("uid://bak1mo1icnsxi")
@export var explode_scene : PackedScene = preload("uid://bkp0cxcybg7s2")
@export var shoot_time : int = 150
@export var safe_distance : float = 80.0

var cannon : Node2D
var player : Node2D
var shoot_timer : int

func _ready() -> void:
	var fc = func():
		player = get_tree().get_first_node_in_group("player") as Node2D
	fc.call_deferred()
	cannon = get_node(path_to_cannon)

func _physics_process(_delta: float) -> void:
	var is_safe : bool
	if player.position.x > cannon.position.x - safe_distance \
	and player.position.x < cannon.position.x + safe_distance:
		is_safe = true
	else:
		is_safe = false

	if is_safe:
		return
	shoot_timer += 1
	if shoot_timer >= shoot_time:
		shoot_timer = 0
		launch()

func launch() -> void:
	var left : bool = player.position.x < cannon.position.x

	var bill = bullet_bill_scene.instantiate() as Node2D
	bill.position = cannon.position
	bill.set_meta("bill_direction", -1 if left else 1)
	cannon.add_sibling(bill)

	var explode = explode_scene.instantiate() as Node2D
	explode.position = bill.position + Vector2(-16.0 if left else 16.0, 0)
	cannon.add_sibling(explode)

	emit_signal("play_sound_launch")
