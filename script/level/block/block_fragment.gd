extends Node2D

class_name BlockFragment

@export var sprite: Sprite2D
var speed_x: float
var speed_y: float
var _gravity: float = 1800.0
var _random = RandomNumberGenerator.new()
var _angular: float

func _ready():
	_angular = (_random.randi_range(0, 19) - _random.randi_range(0, 19)) * 120.0

func _physics_process(delta):
	position.x += speed_x * delta
	position.y += speed_y * delta
	speed_y += _gravity * delta
	rotation_degrees += _angular * delta
	