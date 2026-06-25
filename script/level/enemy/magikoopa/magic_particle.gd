extends AnimatedSprite2D

@onready var magic_particle: AnimatedSprite2D = $"."


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	magic_particle.queue_free()
