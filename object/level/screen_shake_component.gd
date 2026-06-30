extends Node

@export var shake_duration: int = 8
@export var shake_intensity: float = 4.0

var timer: int = 0
var rng = RandomNumberGenerator.new()
var camera: Camera2D


func _ready():
	camera = get_tree().get_first_node_in_group("level_camera") as Camera2D


func _physics_process(_delta: float) -> void:
	if timer > 0:
		timer -= 1
		if camera:
			camera.offset = Vector2(
				#rng.randf_range(-shake_intensity, shake_intensity),
				0.0,
				rng.randf_range(-shake_intensity, shake_intensity)
			)
		if timer <= 0:
			_reset_shake()


func _on_screen_shake() -> void:
	timer = shake_duration


func _reset_shake() -> void:
	if camera:
		camera.offset = Vector2.ZERO
