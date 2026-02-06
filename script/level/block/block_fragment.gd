extends Node2D

class_name BlockFragment

@export var sprite: Sprite2D
const FRAMERATE_ORIGIN: float = 60.0
var speed_x: float
var speed_y: float
var _gravity: float = 0.5
var _random = RandomNumberGenerator.new()
var _angular: float

func _ready():
	_angular = _random.randi_range(0, 19) - _random.randi_range(0, 19)

func _physics_process(delta):
	position.x += speed_x * FRAMERATE_ORIGIN * delta
	position.y += speed_y * FRAMERATE_ORIGIN * delta
	speed_y += _gravity * FRAMERATE_ORIGIN * delta
	rotation_degrees += _angular * FRAMERATE_ORIGIN * delta
	